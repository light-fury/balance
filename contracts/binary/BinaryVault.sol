// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "erc721a-upgradeable/contracts/extensions/ERC721AQueryableUpgradeable.sol";

import "../interfaces/binary/IBinaryVault.sol";

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

    uint256 public vaultId;
    IERC20Upgradeable public underlyingToken;

    /// @dev Whitelisted markets, only whitelisted markets can take money out from the vault.
    mapping(address => bool) public whitelistedMarkets;

    /// token Id => amount, represents user share on the vault
    mapping(uint256 => uint256) stakedAmounts;
    uint256 totalStaked;

    uint256 feeAccrued;

    event Staked(address user, uint256 tokenId, uint256 amount);
    event Unstaked(address user, uint256 amount);

    /**
     * @notice one time initialize
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 vaultId_,
        address underlyingToken_
    ) public initializerERC721A initializer {
        __ERC721A_init(name_, symbol_);
        __Ownable_init();
        __Pausable_init();

        require(underlyingToken_ != address(0), "MISSING_VAULT");
        underlyingToken = IERC20Upgradeable(underlyingToken_);
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

        emit Staked(user, tokenId, amount);
    }

    function claim(uint256 amount, address to) external {
        require(amount > 0, "zero amount");
        require(whitelistedMarkets[msg.sender], "not whitelisted");
        require(to != address(0), "invalid target");

        underlyingToken.safeTransfer(to, amount);
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
        underlyingToken.safeTransfer(user, amount);

        emit Unstaked(user, amount);
    }
}
