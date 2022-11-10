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
    mapping(uint256 => uint256) stakedAmounts;
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
        require(market != address(0), "invalid market");
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
        require(user != address(0), "zero address");
        require(amount > 0, "zero amount");

        // Transfer underlying token from user to the vault
        underlyingToken.safeTransferFrom(user, address(this), amount);

        // Burn prev token share and mint new one
        uint256[] memory tokenIds = tokensOfOwner(user);
        uint256 stakedAmount;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            stakedAmount += stakedAmounts[tokenIds[i]];
            delete stakedAmounts[tokenIds[i]];
            _burn(tokenIds[i], false);
        }
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
        require(amount > 0, "zero amount");

        // collect previous deposits
        uint256[] memory tokenIds = tokensOfOwner(user);
        require(tokenIds.length > 0, "NFTS_NOT_FOUND");

        uint256 stakedAmount;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            stakedAmount += stakedAmounts[tokenIds[i]];
            delete stakedAmounts[tokenIds[i]];
            _burn(tokenIds[i], true);
        }
        totalStaked -= amount;
        watermark -= amount;
        underlyingToken.safeTransfer(user, amount);

        emit Unstaked(user, amount);
    }

    function _cutTradingFee(uint256 amount) internal returns (uint256) {
        uint256 fee = (amount * config.tradingFee()) / 10000;
        feeAccrued += fee;
        return amount - fee;
    }

    /**
     * @notice Deposit bets on the vault
     * @dev Only markets can call this function
     * @param from Betee's address
     * @param amount Amount of underlying tokens to bet
     */
    function bet(address from, uint256 amount) external onlyMarket {
        if (amount == 0) revert ZERO_AMOUNT();
        if (from == address(0)) revert ZERO_ADDRESS();

        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);
        bets[from] += amount;
        watermark += amount;
    }

    /**
     * @notice Claim winning rewards from the vault
     * @dev Only markets can call this function
     * @param to Address of winner
     * @param amount Amount of rewards to claim
     */
    function claim(address to, uint256 amount) external onlyMarket {
        if (amount == 0) revert ZERO_AMOUNT();
        if (to == address(0)) revert ZERO_ADDRESS();
        if (bets[to] < amount) revert NO_BETS_TO_CLAIM(to, amount);

        bets[to] -= amount;
        uint256 claimAmount = _cutTradingFee(amount);
        watermark -= claimAmount;
        underlyingToken.safeTransfer(to, claimAmount);
    }
}
