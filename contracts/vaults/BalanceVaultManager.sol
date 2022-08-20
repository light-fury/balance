// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./BalanceVault.sol";

/// @notice Creates new balance vaults
contract BalanceVaultManager is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    address public vaultTemplate;

    ///
    /// events
    ///

    /// @notice informs about creating new vault
    /// @param _creator caller of the function
    /// @param _vault CA of the vault
    /// @param _template vault template CA from which it was created
    event VaultCreated(
        address _creator,
        address _vault,
        address _template
    );

    ///
    /// business logic
    ///

    /// @notice creates new vault
    /// @param _ownerName name of the vault owner
    /// @param _ownerDescription description of vault purpose
    /// @param _ownerContactInfo contact info of vault owner
    /// @param _ownerWallet wallet of the owner where funds will be managed
    /// @param _funding funding of the vault, with 18 decimals
    /// @param _ending timestamp to the payout of given APR
    /// @param _apr apr in 2 decimals
    /// @return _vaultAddress actual address of preconfigured vault
    function createVault(
        string calldata _ownerName,
        string calldata _ownerDescription,
        string calldata _ownerContactInfo,
        address _ownerWallet,
        uint _funding,
        uint _ending,
        uint _apr
    ) external nonReentrant returns (address _vaultAddress) {

        // EIP1167 clone factory
        _vaultAddress = Clones.clone(vaultTemplate);

        BalanceVault vault = BalanceVault(_vaultAddress);
        vault.initialize(_ownerName, _ownerDescription, _ownerContactInfo, _ownerWallet, _funding, _ending, _apr);
        vault.transferOwnership(msg.sender);

        // remember in history
        emit VaultCreated(msg.sender, _vaultAddress, vaultTemplate);
    }

    ///
    /// management
    ///

    function setVaultTemplate(address _vaultTemplate) external  onlyOwner {
        require(_vaultTemplate != address(0), "EMPTY_ADDRESS");
        vaultTemplate = _vaultTemplate;
    }

    function recoverTokens(IERC20 token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}