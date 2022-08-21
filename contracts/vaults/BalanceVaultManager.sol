// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./BalanceVault.sol";
import "./BalanceVaultShare.sol";
import "../utils/ArrayUtils.sol";

/// @notice Creates new balance vaults
contract BalanceVaultManager is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    address public immutable DAO;
    address public immutable USDB;

    address public vaultTemplate;
    address public nftTemplate;

    /// fee on borrowers total amount raised, 2 decimals percent, 100% is 10000
    uint public feeBorrower;
    /// fee on lenders return in case usdb is used, 2 decimals percent, 100% is 10000
    uint public feeLenderUsdb;
    /// fee on lenders return in case other token is used, 2 decimals percent, 100% is 10000
    uint public feeLenderOther;

    /// vetted tokens
    address[] public allowedTokens;
    mapping(address => bool) allowedTokensMapping;

    /// @param _DAO gnosis multisig address
    /// @param _USDB usdb address
    /// @param _feeBorrower fee on borrowers total amount raised, 2 decimals percent, 100% is 10000
    /// @param _feeLenderUsdb fee on lenders return in case usdb is used, 2 decimals percent, 100% is 10000
    /// @param _feeLenderOther fee on lenders return in case other token is used, 2 decimals percent, 100% is 10000
    constructor(address _DAO, address _USDB, uint _feeBorrower, uint _feeLenderUsdb, uint _feeLenderOther) {
        require(_DAO != address(0));
        DAO = _DAO;
        require(_USDB != address(0));
        USDB = _USDB;
        feeBorrower = _feeBorrower;
        feeLenderUsdb = _feeLenderUsdb;
        feeLenderOther = _feeLenderOther;
    }

    ///
    /// events
    ///

    /// @notice informs about creating new vault
    /// @param _creator caller of the function
    /// @param _vault CA of the vault
    /// @param _vaultTemplate vault template CA from which it was created
    /// @param _nftTemplate nft template CA which is used for share
    event VaultCreated(
        address _creator,
        address _vault,
        address _vaultTemplate,
        address _nftTemplate
    );

    ///
    /// business logic
    ///

    /// @notice creates new vault
    /// @param _ownerInfos name, description and contact info
    /// @param _ownerWallet wallet of the owner where funds will be managed
    /// @param _fundingAmount funding of the vault, with 18 decimals
    /// @param _allowedTokens allowed tokens which are 1:1 used for funding
    /// @param _freezeTimestamp timestamp to freeze this fundrising
    /// @param _repaymentTimestamp timestamp to the payout of given APR
    /// @param _apr apr in 2 decimals, 10000 is 100%
    /// @return _vaultAddress actual address of preconfigured vault
    function createVault(
        string[] calldata _ownerInfos,
        address _ownerWallet,
        uint _fundingAmount,
        address[] calldata _allowedTokens,
        uint _freezeTimestamp,
        uint _repaymentTimestamp,
        uint _apr
    ) external nonReentrant returns (address _vaultAddress) {
        require(vaultTemplate != address(0), "MISSING_VAULT_TEMPLATE");
        require(nftTemplate != address(0), "MISSING_NFT_TEMPLATE");

        require(_freezeTimestamp < _repaymentTimestamp, "VAULT_FREEZE_SHOULD_BE_BEFORE_PAYOUT");
        require(_freezeTimestamp > block.timestamp, "VAULT_FREEZE_SHOULD_BE_IN_FUTURE");

        // FIXME add links in separate array
        require(_ownerInfos.length == 3, "INFOS_MISSING");

        for (uint i = 0; i < _allowedTokens.length; i++) {
            require(allowedTokensMapping[_allowedTokens[i]], "TOKEN_NOT_ALLOWED");
        }

        // EIP1167 clone factory
        _vaultAddress = Clones.clone(vaultTemplate);
        address nftAddress = Clones.clone(nftTemplate);

        VaultParams memory param = VaultParams({
        ownerInfos : _ownerInfos,
        ownerWallet : _ownerWallet,
        nftAddress : nftAddress,
        fundingAmount : _fundingAmount,
        allowedTokens : _allowedTokens,
        freezeTimestamp : _freezeTimestamp,
        repaymentTimestamp : _repaymentTimestamp,
        apr : _apr,
        feeBorrower : feeBorrower,
        feeLenderUsdb : feeLenderUsdb,
        feeLenderOther : feeLenderOther
        });
        BalanceVault vault = BalanceVault(_vaultAddress);
        vault.initialize(param);
        vault.transferOwnership(msg.sender);

        BalanceVaultShare share = BalanceVaultShare(nftAddress);
        share.initialize(_vaultAddress);
        // owner of NFT is only for transferring tokens sent to NFT CA by mistake
        share.transferOwnership(msg.sender);

        // remember in history
        emit VaultCreated(msg.sender, _vaultAddress, vaultTemplate, nftTemplate);
    }

    ///
    /// management
    ///

    /// @notice change vault template, e.g. can deploy new version with same signature
    /// @param _vaultTemplate CA for new vault
    function setVaultTemplate(address _vaultTemplate) external onlyOwner {
        require(_vaultTemplate != address(0), "EMPTY_ADDRESS");
        vaultTemplate = _vaultTemplate;
    }

    /// @notice change nft template, e.g. can deploy new version with same signature
    /// @param _nftTemplate CA for new vault nft
    function setNftTemplate(address _nftTemplate) external onlyOwner {
        require(_nftTemplate != address(0), "EMPTY_ADDRESS");
        nftTemplate = _nftTemplate;
    }

    /// @notice sets fee for total amount raise
    /// @param _feeBorrower fee on borrowers total amount raised, 2 decimals percent, 100% is 10000
    function setFeeBorrower(uint _feeBorrower) external onlyOwner {
        require(_feeBorrower < 2000, "FEE_TOO_HIGH");
        feeBorrower = _feeBorrower;
    }

    /// @notice sets fee for usdb token
    /// @param _feeLenderUsdb fee on lenders return in case usdb is used, 2 decimals percent, 100% is 10000
    function setFeeLenderUsdb(uint _feeLenderUsdb) external onlyOwner {
        require(_feeLenderUsdb < 5000, "FEE_TOO_HIGH");
        feeLenderUsdb = _feeLenderUsdb;
    }

    /// @notice sets fee for other tokens
    /// @param _feeLenderOther fee on lenders return in case other token is used, 2 decimals percent, 100% is 10000
    function setFeeLenderOther(uint _feeLenderOther) external onlyOwner {
        require(_feeLenderOther < 5000, "FEE_TOO_HIGH");
        feeLenderOther = _feeLenderOther;
    }

    /// @notice add allowed token
    /// @param _token token CA
    function setAllowedToken(address _token) external onlyOwner {
        address[] memory tokens = new address[](allowedTokens.length + 1);
        for (uint i = 0; i < allowedTokens.length; i++) {
            tokens[i] = allowedTokens[i];
            require(allowedTokens[i] != _token, "TOKEN_ALREADY_USED");
        }
        tokens[allowedTokens.length] = _token;
        allowedTokens = tokens;
        allowedTokensMapping[_token] = true;
    }

    /// @notice remove allowed token
    /// @param _token token to remove with its mapping
    function removeAllowedToken(address _token) external onlyOwner {
        uint index = ArrayUtils.arrayIndex(allowedTokens, _token, allowedTokens.length);
        require(index != type(uint).max, "TOKEN_NOT_FOUND");

        address[] memory tokens = new address[](allowedTokens.length - 1);
        for (uint i = 0; i < allowedTokens.length; i++) {
            if (i < index) tokens[i] = allowedTokens[i];
            else if (i == index) continue;
            else {
                tokens[i - 1] = allowedTokens[i];
            }
        }

        allowedTokens = tokens;
        allowedTokensMapping[_token] = false;
    }

    function recoverTokens(IERC20 token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}