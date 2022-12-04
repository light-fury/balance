// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "erc721a-upgradeable/contracts/extensions/ERC721AQueryableUpgradeable.sol";

import "../interfaces/binary/IBinaryVault.sol";
import "../interfaces/binary/IBinaryConfig.sol";
import "./BinaryErrors.sol";

/**
 * @title Vault of Binary Option Trading
 * @notice This vault is holding one underlying tokens in it
 * @author Balance Capital, @gmspacex
 */
contract BinaryVault is
    ERC721AQueryableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IBinaryVault
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IBinaryConfig public config;

    uint256 public vaultId;
    IERC20Upgradeable public underlyingToken;

    /// @dev Whitelisted markets, only whitelisted markets can take money out from the vault.
    mapping(address => bool) public whitelistedMarkets;

    /// token Id => amount, represents user share on the vault
    mapping(uint256 => uint256) public stakedAmounts;
    /// Binary Players => Bet Amount
    mapping(address => uint256) bets;

    uint256 public watermark;
    uint256 public totalStaked;
    uint256 public feeAccrued;

    modifier onlyMarket() {
        if (!whitelistedMarkets[msg.sender]) revert NOT_FROM_MARKET(msg.sender);
        _;
    }

    /**
     * @notice one time initialize
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 vaultId_,
        address underlyingToken_,
        address config_
    ) public initializerERC721A initializer {
        __ERC721A_init(name_, symbol_);
        __Ownable_init();
        __Pausable_init();

        if (underlyingToken_ == address(0)) revert ZERO_ADDRESS();
        if (config_ == address(0)) revert ZERO_ADDRESS();

        underlyingToken = IERC20Upgradeable(underlyingToken_);
        config = IBinaryConfig(config_);
        vaultId = vaultId_;
    }

    /**
     * @notice Pause the vault, it affects stake and unstake
     * @dev Only owner can call this function
     */
    function pauseVault() external onlyOwner {
        _pause();
    }

    function unpauseVault() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Whitelist market on the vault
     * @dev Only owner can call this function
     * @param market Market contract address
     * @param whitelist Whitelist or Blacklist
     */
    function whitelistMarket(address market, bool whitelist)
        external
        onlyOwner
    {
        if (market == address(0)) revert ZERO_ADDRESS();
        whitelistedMarkets[market] = whitelist;
    }

    /**
     * @notice Returns the tokenIds being hold by the owner
     * @param owner Owner address
     * @return tokenIds Array of tokenIds owned by the given address
     */
    function tokensOfOwner(address owner)
        public
        view
        override
        returns (uint256[] memory)
    {
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            uint256 tokenIdsLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            TokenOwnership memory ownership;
            for (
                uint256 i = _startTokenId();
                tokenIdsIdx != tokenIdsLength;
                ++i
            ) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    /**
     * @notice Stake underlying tokens to the vault
     * @param user Staker's address
     * @param amount Amount of underlying tokens to stake
     */
    function stake(address user, uint256 amount)
        external
        override
        whenNotPaused
    {
        if (user == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();

        // Transfer underlying token from user to the vault
        underlyingToken.safeTransferFrom(user, address(this), amount);

        // Burn prev token share
        uint256[] memory tokenIds = tokensOfOwner(user);
        uint256 stakedAmount;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            stakedAmount += stakedAmounts[tokenIds[i]];
            delete stakedAmounts[tokenIds[i]];
            _burn(tokenIds[i], false);
        }
        // Mint new one
        uint256 tokenId = _nextTokenId();
        stakedAmounts[tokenId] = stakedAmount + amount;
        _mint(user, 1);

        totalStaked += amount;
        watermark += amount;

        emit Staked(user, tokenId, amount);
    }

    /**
     * @notice Unstake underlying tokens from the vault
     * @param user Staker's address
     * @param amount Amount of underlying tokens to unstake
     */
    function unstake(address user, uint256 amount)
        external
        override
        whenNotPaused
    {
        if (amount == 0) revert ZERO_AMOUNT();
        if (user == address(0)) revert ZERO_ADDRESS();

        // collect previous deposits and burn
        uint256[] memory tokenIds = tokensOfOwner(user);
        if (tokenIds.length == 0) revert NO_DEPOSIT(user);

        uint256 stakedAmount;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            stakedAmount += stakedAmounts[tokenIds[i]];
            delete stakedAmounts[tokenIds[i]];
            _burn(tokenIds[i], true);
        }
        if (amount > stakedAmount) revert EXCEED_BALANCE(user, amount);

        // mint new one when some dust left
        if (amount < stakedAmount) {
            uint256 tokenId = _nextTokenId();
            stakedAmounts[tokenId] = stakedAmount - amount;
            _mint(user, 1);
        }

        totalStaked -= amount;
        watermark -= amount;
        underlyingToken.safeTransfer(user, amount);

        emit Unstaked(user, amount);
    }

    /**
     * @notice Cut trading fee when claiming winning bets
     * @dev Transfer fees accrued to the treasury wallet
     * @param amount Amount to claim
     * @return claimAmount Actual claimable amount
     */
    function _cutTradingFee(uint256 amount) internal returns (uint256) {
        uint256 fee = (amount * config.tradingFee()) / config.FEE_BASE();
        underlyingToken.safeTransfer(config.treasury(), fee);
        feeAccrued += fee;

        return amount - fee;
    }

    /**
     * @notice Claim winning rewards from the vault
     * @dev Only markets can call this function
     * @param user Address of winner
     * @param amount Amount of rewards to claim
     */
    function claimBettingRewards(address user, uint256 amount) external onlyMarket {
        if (amount == 0) revert ZERO_AMOUNT();
        if (user == address(0)) revert ZERO_ADDRESS();
        if (bets[user] < amount) revert EXCEED_BETS(user, amount);

        bets[user] -= amount;
        uint256 claimAmount = _cutTradingFee(amount);
        watermark -= claimAmount;
        underlyingToken.safeTransfer(user, claimAmount);

        emit Claimed(user, amount);
    }
}
