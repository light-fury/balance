// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @notice balance vault
contract BalanceVault is OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// name of the vault owner
    string public ownerName;
    /// description of the vault owner
    string public ownerDescription;
    /// contact info of the vault owner
    string public ownerContactInfo;

    /// unmodifiable wallet of the vault owner where all funds are going
    address public ownerWallet;
    /// unmodifiable funding amount with 18 decimals
    uint public funding;
    /// unmodifiable timestamp to the payout of given APR
    uint public ending;
    /// unmodifiable apr in 2 decimals
    uint public apr;

    /// @notice initialize newly created vault
    /// @param _ownerName name of the vault owner
    /// @param _ownerDescription description of vault purpose
    /// @param _ownerContactInfo contact info of vault owner
    /// @param _ownerWallet wallet of the owner where funds will be managed
    /// @param _funding funding of the vault, with 18 decimals
    /// @param _ending timestamp to the payout of given APR
    /// @param _apr apr in 2 decimals
    // Take note of the initializer modifiers.
    // - `initializer` for OpenZeppelin's `OwnableUpgradeable`.
    function initialize(
        string calldata _ownerName,
        string calldata _ownerDescription,
        string calldata _ownerContactInfo,
        address _ownerWallet,
        uint _funding,
        uint _ending,
        uint _apr
    ) initializer public {
        __Ownable_init();

        ownerName = _ownerName;
        ownerDescription = _ownerDescription;
        ownerContactInfo = _ownerContactInfo;
        ownerWallet = _ownerWallet;
        funding = _funding;
        ending = _ending;
        apr = _apr;
    }

    ///
    /// management
    ///

    function recoverTokens(IERC20Upgradeable token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}