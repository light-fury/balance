// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "../interfaces/binary/IBinaryVault.sol";
import "../interfaces/binary/IBinaryConfig.sol";
import "./BinaryErrors.sol";

/**
 * @title Vault of Binary Option Trading
 * @notice This vault is holding one underlying tokens in it
 * @author Balance Capital, @gmspacex
 */
contract BinaryVault is
    ERC721AQueryable,
    Pausable,
    IBinaryVault
{
    using SafeERC20 for IERC20;

    IBinaryConfig public config;

    uint256 public vaultId;
    IERC20 public underlyingToken;

    /// @dev Whitelisted markets, only whitelisted markets can take money out from the vault.
    mapping(address => bool) public whitelistedMarkets;

    /// token Id => amount, represents user share on the vault
    mapping(uint256 => uint256) public stakedAmounts;

    uint256 public totalStaked;
    uint256 public feeAccrued;
    
    address public adminAddress;
    address public vaultManager;
    modifier onlyMarket() {
        if (!whitelistedMarkets[msg.sender]) revert NOT_FROM_MARKET(msg.sender);
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 vaultId_,
        address underlyingToken_,
        address config_,
        address admin_
    ) ERC721A(name_, symbol_) Pausable() {
        if (underlyingToken_ == address(0)) revert ZERO_ADDRESS();
        if (config_ == address(0)) revert ZERO_ADDRESS();

        underlyingToken = IERC20(underlyingToken_);
        config = IBinaryConfig(config_);
        vaultId = vaultId_;
        adminAddress = admin_;
    }

    /**
     * @notice Pause the vault, it affects stake and unstake
     * @dev Only owner can call this function
     */
    function pauseVault() external onlyAdmin {
        _pause();
    }

    function unpauseVault() external onlyAdmin {
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
        onlyAdmin
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

        uint256 claimAmount = _cutTradingFee(amount);
        underlyingToken.safeTransfer(user, claimAmount);
    }

    /**
    * @notice Change admin
    */

    function setAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        adminAddress = _newAdmin;
    }

    /**
    * @dev change vault manager address
    */
    function setVaultManager(address _newManager) external onlyAdmin {
        require(_newManager != address(0), "Invalid address");
        vaultManager = _newManager;
        setApprovalForAll(_newManager, true);
    }
}
