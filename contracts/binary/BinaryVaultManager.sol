// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/binary/IBinaryVault.sol";
import "../interfaces/binary/IBinaryVaultManager.sol";

contract BinaryVaultManager is OwnableUpgradeable, IBinaryVaultManager {
    mapping(address => IBinaryVault) public vaults;

    function addVault(address uToken, address vault) external onlyOwner {
        require(address(uToken) != address(0), "invalid underlying token");
        require(address(vault) != address(0), "invalid vault address");
        require(address(vaults[uToken]) == address(0), "already set");

        vaults[uToken] = IBinaryVault(vault);
    }

    function migrateVault(address uToken, address vault) external onlyOwner {
        require(address(uToken) != address(0), "invalid underlying token");
        require(address(vault) != address(0), "invalid vault address");
        require(address(vaults[uToken]) != address(0), "not set");

        vaults[uToken] = IBinaryVault(vault);
    }

    function stake(address uToken, uint256 amount) external override {
        IBinaryVault vault = vaults[uToken];
        require(address(vault) != address(0), "invalid uToken");
        require(amount > 0, "zero amount");

        vault.stake(msg.sender, amount);
    }

    function unstake(address uToken, uint256 amount) external override {
        IBinaryVault vault = vaults[uToken];
        require(address(vault) != address(0), "invalid uToken");
        require(amount > 0, "zero amount");

        vault.stake(msg.sender, amount);
    }
}
