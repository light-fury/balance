// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
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
    IBinaryVault,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    IBinaryConfig public config;

    uint256 public vaultId;
    IERC20 public underlyingToken;

    /// @dev Whitelisted markets, only whitelisted markets can take money out from the vault.
    mapping(address => bool) public whitelistedMarkets;

    /// @dev share balances (token id => share balance)
    mapping(uint256 => uint256) public shareBalances;
    
    uint256 public totalShareSupply;

    uint256 public feeAccrued;
    
    address public adminAddress;

    event AdminChanged(address indexed admin);
    event ConfigChanged(address indexed config);
    event WhitelistMarketChanged(address indexed market, bool enabled);
    event NewLiquidityAdded(address indexed user, uint256 tokenId, uint256 amount, uint256 shareAmount);
    event LiquidityAdded(address indexed user, uint256 oldTokenId, uint256 newTokenId, uint256 amount, uint256 newShareAmount);
    event PositionMerged(address indexed user, uint256[] tokenIds, uint256 newTokenId);
    event LiquidityRemoved(address indexed user, uint256[] tokenids, uint256 newTokenId, uint256 amount, uint256 shareAmount, uint256 newShares);
    event LiquidityRemovedFromPosition(address indexed user, uint256 tokenId, uint256 amount, uint256 shares, uint256 newTokenId, uint256 newShare);

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

        emit WhitelistMarketChanged(market, whitelist);
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
    * @dev Add New liquidity
    * @param user Receipt for share
    * @param amount Underlying token amount
    */
    function addNewLiquidityPosition(address user, uint256 amount)
        external
        override
        whenNotPaused
        nonReentrant
    {
        if (user == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();
        // Mint new one
        uint256 tokenId = _nextTokenId();
        _mint(user, 1);

        uint256 underlyingTokenBalance = underlyingToken.balanceOf(address(this));
        // Transfer underlying token from user to the vault
        underlyingToken.safeTransferFrom(user, address(this), amount);

        uint256 newShares = 0;
        if (totalShareSupply > 0) {
            newShares = (amount * totalShareSupply) / underlyingTokenBalance;
        } else {
            newShares = amount;
            require(newShares > MINIMUM_LIQUIDITY, "Insufficient amount");
        }

        shareBalances[tokenId] = newShares;
        
        totalShareSupply += newShares;

        emit NewLiquidityAdded(user, tokenId, amount, newShares);
    }

    /**
    * @dev Add liquidity. Burn existing token, mint new one.
    * @param user Receipt for share
    * @param amount Underlying token amount
    * @param tokenId nft id to be added liquidity. This should be existing id.
    */
    function addLiquidityPosition(address user, uint256 amount, uint256 tokenId)
        external
        override
        whenNotPaused
        nonReentrant
    {
        if (user == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();
        require(_exists(tokenId), "Non exists token");
        require(ownerOf(tokenId) == user, "Not owner");
        require(user == msg.sender || isApprovedForAll(user, msg.sender), "Not approved or owner");

        uint256 underlyingTokenBalance = underlyingToken.balanceOf(address(this));
        // Transfer underlying token from user to the vault
        underlyingToken.safeTransferFrom(user, address(this), amount);

        uint256 newShares = 0;
        if (totalShareSupply > 0) {
            newShares = (amount * totalShareSupply) / underlyingTokenBalance;
        } else {
            newShares = amount;
            require(newShares > MINIMUM_LIQUIDITY, "Insufficient amount");
        }

        uint256 currentShare = shareBalances[tokenId];
        // Burn existing one
        _burn(tokenId);
        delete shareBalances[tokenId];
        // Mint new one
        uint256 newTokenId = _nextTokenId();
        _mint(user, 1);

        shareBalances[newTokenId] = currentShare + newShares;
        
        totalShareSupply += newShares;

        // TODO Update event
        emit LiquidityAdded(user, tokenId, newTokenId, amount, newShares);
    }

    /**
    * @dev Merge tokens into one, Burn existing ones and mint new one
    * @param user receipent
    * @param tokenIds Token ids which will be merged
    */
    function mergePositions(address user, uint256[] memory tokenIds) public {
        require(user != address(0), "Invalid user");

        uint256 shareAmounts = 0;
        for (uint256 i; i < tokenIds.length; i = i + 1) {
            uint256 tokenId = tokenIds[i];
            require(_exists(tokenId), "Non exists token");
            require(ownerOf(tokenId) == user, "Not owner");
            require(user == msg.sender || isApprovedForAll(user, msg.sender), "Non owner or approved");

            shareAmounts += shareBalances[tokenId];
            _burn(tokenId);
            delete shareBalances[tokenId];
        }

        uint256 _newTokenId = _nextTokenId();
        _mint(user, 1);
        shareBalances[_newTokenId] = shareAmounts;

        emit PositionMerged(user, tokenIds, _newTokenId);
    }

    /**
    * @dev Merge all owned nfts into new one
    */
    function mergeAllPositions(address user) external {
        uint256[] memory tokenIds = tokensOfOwner(user);
        mergePositions(user, tokenIds);
    }

    /**
    *@dev Remove share, and merge to one
    *@param user receipent
    *@param shareAmount Share amount
    */
    function removeLiquidity(address user, uint256 shareAmount)
        external
        override
        whenNotPaused
        nonReentrant
    {
        if (shareAmount == 0) revert ZERO_AMOUNT();
        require(msg.sender == user || isApprovedForAll(user, msg.sender), "Not approved");

        uint256[] memory tokenIds = tokensOfOwner(user);

        uint256 shareAmounts = 0;
        for (uint256 i; i < tokenIds.length; i = i + 1) {
            uint256 tokenId = tokenIds[i];
            shareAmounts += shareBalances[tokenId];
            _burn(tokenId);
            delete shareBalances[tokenId];
        }

        require(shareAmount <= shareAmounts, "Insufficient share amount");

        uint256 underlyingTokenBalance = underlyingToken.balanceOf(address(this));

        uint256 _newTokenId;
        if (shareAmounts > shareAmount) {
            // Mint dust nft
            _newTokenId = _nextTokenId();
            _mint(user, 1);
            shareBalances[_newTokenId] = shareAmounts - shareAmount;
        }

        // Transfer underlying token
        uint256 _underlyingTokenAmount = shareAmount * underlyingTokenBalance / totalShareSupply;
        underlyingToken.safeTransfer(user, _underlyingTokenAmount);

        totalShareSupply -= shareAmount;

        emit LiquidityRemoved(user, tokenIds, _underlyingTokenAmount, shareAmount, _newTokenId, shareAmounts - shareAmount);
    }

    /**
    * @dev Remove liquidity from position
    * @param user Receipent
    * @param tokenId position that where remove liquidity from
    * @param shareAmount amount of share
    */
    function removeLiquidityPosition(address user, uint256 tokenId, uint256 shareAmount)
        external 
        override
        whenNotPaused
        nonReentrant
    {
        if (shareAmount == 0) revert ZERO_AMOUNT();
        require(_exists(tokenId), "Invalid token id");
        require(ownerOf(tokenId) == user, "Not owner");
        require(msg.sender == user || isApprovedForAll(user, msg.sender), "Not approved");
        uint256 shareBalance = shareBalances[tokenId];
        require(shareBalance >= shareAmount, "Insufficient shares");
        _burn(tokenId);
        delete shareBalances[tokenId];

        uint256 newTokenId;
        if (shareAmount < shareBalance) {
            // Mint new one for dust
            newTokenId = _nextTokenId();
            _mint(user, 1);
            shareBalances[newTokenId] = shareBalance - shareAmount;
        }

        uint256 underlyingTokenBalance = underlyingToken.balanceOf(address(this));
        // Transfer underlying token
        uint256 _underlyingTokenAmount = shareAmount * underlyingTokenBalance / totalShareSupply;
        underlyingToken.safeTransfer(user, _underlyingTokenAmount);
        
        emit LiquidityRemovedFromPosition(user, tokenId, _underlyingTokenAmount, shareAmount, newTokenId, shareBalance - shareAmount);
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
    * @dev Get shares of user.
    */
    function getSharesOfUser(address user) 
        public 
        view 
        returns(uint256 shares, uint256 underlyingTokenAmount)
    {
        uint256 underlyingTokenBalance = underlyingToken.balanceOf(address(this));

        uint256[] memory tokenIds = tokensOfOwner(user);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            shares += shareBalances[tokenIds[i]];
        }
        
        underlyingTokenAmount = shares * underlyingTokenBalance / totalShareSupply; 
    }

    /**
    * @notice Change admin
    */

    function setAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        adminAddress = _newAdmin;

        emit AdminChanged(_newAdmin);
    }

    /**
    * @dev set config
    */
    function setConfig(IBinaryConfig _config) external onlyAdmin {
        require(address(_config) != address(0), "Invalid address");
        config = _config;

        emit ConfigChanged(address(_config));
    }
}
