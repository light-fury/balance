// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./BalanceVault.sol";
import "./BalanceVaultShare.sol";
import "../utils/ArrayUtils.sol";

interface IBalancePassManager {
    function getDiscountFromFee(address _user, uint _fee) external view returns (uint, uint);
}

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
    mapping(address => bool) public allowedTokensMapping;

    /// extension to support configurable discounts
    address public balancePassManager;

    /// repository for all generated vaults
    address[] generatedVaults;

    struct BalanceVaultDto {
        string[] ownerInfos;
        string[] ownerContacts;
        address ownerWallet;
        uint fundingAmount;
        address[] allowedTokens;
        uint freezeTimestamp;
        uint repaymentTimestamp;
        uint apr;
    }

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

        setAllowedToken(_USDB);
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

    event LogBytes(bytes data);

    ///
    /// business logic
    ///

    /// @notice creates new vault
    /// @param _ownerInfos name, description
    /// @param _ownerContacts contact info like twitter links, website, etc
    /// @param _ownerWallet wallet of the owner where funds will be managed
    /// @param _fundingAmount funding of the vault, with 18 decimals
    /// @param _allowedTokens allowed tokens which are 1:1 used for funding
    /// @param _freezeTimestamp timestamp to freeze this fundrising
    /// @param _repaymentTimestamp timestamp to the payout of given APR
    /// @param _apr apr in 2 decimals, 10000 is 100%
    /// @return _vaultAddress actual address of preconfigured vault
    function createVault(
        string[] calldata _ownerInfos,
        string[] calldata _ownerContacts,
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

        require(_ownerInfos.length == 2, "INFOS_MISSING");

        for (uint i = 0; i < _allowedTokens.length; i++) {
            require(allowedTokensMapping[_allowedTokens[i]], "TOKEN_NOT_ALLOWED");
        }

        // EIP1167 clone factory
        _vaultAddress = Clones.clone(vaultTemplate);
        address nftAddress = Clones.clone(nftTemplate);

        VaultParams memory param = VaultParams({
        ownerInfos : _ownerInfos,
        ownerContacts : _ownerContacts,
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

        // persist in paging repository
        generatedVaults[generatedVaults.length] = _vaultAddress;

        // remember in history
        emit VaultCreated(msg.sender, _vaultAddress, vaultTemplate, nftTemplate);
    }

    /// @notice get amount and fee part from fee
    /// @param _user given user
    /// @param _fee fee to split
    /// @return amount and fee part from given fee
    function getDiscountFromFee(address _user, uint _fee) external returns (uint, uint) {
        if (balancePassManager == address(0)) return (0, _fee);

        try IBalancePassManager(balancePassManager).getDiscountFromFee(_user, _fee) returns (uint _amount, uint _finalFee) {
            return (_amount, _finalFee);
        } catch (bytes memory reason) {
            emit LogBytes(reason);
        }
        return (0, _fee);
    }

    ///
    /// paging
    ///

    /// @notice get generated vaults length for paging
    /// @return generated vaults length for paging
    function getGeneratedVaultsLength() external view returns (uint) {
        return generatedVaults.length;
    }

    /// @notice skip/limit paging on-chain impl
    /// @param _skip how many items from beginning to skip
    /// @param _limit how many items to return in result
    /// @return page of BalanceVaultDto
    function getGeneratedVaultsPage(uint _skip, uint _limit) external view returns (BalanceVaultDto[] memory) {
        if (_skip >= generatedVaults.length) return new BalanceVaultDto[](0);

        uint limit = Math.min(_limit, generatedVaults.length);
        BalanceVaultDto[] memory page = new BalanceVaultDto[](limit);
        uint index = 0;
        for (uint i = _skip; i < limit; i++) {
            BalanceVault vault = BalanceVault(generatedVaults[i]);
            string[] memory ownerInfos = new string[](2);
            ownerInfos[0] = vault.ownerName();
            ownerInfos[1] = vault.ownerDescription();

            page[index++] = BalanceVaultDto({
                ownerInfos : ownerInfos,
                ownerContacts : vault.getOwnerContacts(),
                ownerWallet: vault.ownerWallet(),
                fundingAmount: vault.fundingAmount(),
                allowedTokens: vault.getAllowedTokens(),
                freezeTimestamp: vault.freezeTimestamp(),
                repaymentTimestamp: vault.repaymentTimestamp(),
                apr: vault.apr()
            });
        }
        return page;
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
        require(_feeLenderUsdb < 3000, "FEE_TOO_HIGH");
        feeLenderUsdb = _feeLenderUsdb;
    }

    /// @notice sets fee for other tokens
    /// @param _feeLenderOther fee on lenders return in case other token is used, 2 decimals percent, 100% is 10000
    function setFeeLenderOther(uint _feeLenderOther) external onlyOwner {
        require(_feeLenderOther < 3000, "FEE_TOO_HIGH");
        feeLenderOther = _feeLenderOther;
    }

    /// @notice add allowed token
    /// @param _token token CA
    function setAllowedToken(address _token) public onlyOwner {
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

    /// @notice set manager for balance passes
    /// @param _balancePassManager mgr
    function setBalancePassManager(address _balancePassManager) external onlyOwner {
        balancePassManager = _balancePassManager;
    }

    function recoverTokens(IERC20 token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}