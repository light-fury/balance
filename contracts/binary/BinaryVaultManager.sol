// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/binary/IBinaryVaultManager.sol";
import "./BinaryVault.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BinaryVaultManager is Ownable, IBinaryVaultManager {
    using SafeERC20 for IERC20;
    
    // token => vault
    mapping(address => IBinaryVault) public vaults;
    address[] public underlyingTokens;

    event NewVaultCreated(address indexed vault, address indexed underlyingToken);
    event VaultMigrated(address indexed oldVault, address indexed newVault, address indexed underlyingToken);

    function createNewVault(
        string memory name_,
        string memory symbol_,
        uint256 vaultId_,
        address underlyingToken_,
        address config_,
        bool isMigrate
    ) external onlyOwner {
        require(address(underlyingToken_) != address(0), "invalid underlying token");
        require(address(vaults[underlyingToken_]) == address(0), "already set");
        if (isMigrate) {
            require(address(vaults[underlyingToken_]) != address(0), "not set");
        }

        IBinaryVault _newVault = new BinaryVault(
            name_,
            symbol_,
            vaultId_,
            underlyingToken_,
            config_,
            msg.sender
        );

        _addVault(underlyingToken_, address(_newVault), isMigrate);
    }

    function _migrateVault(address uToken, address vault) internal {
        address oldVault = address(vaults[uToken]);
        uint256 balance = IERC20(uToken).balanceOf(oldVault);
        IERC20(uToken).safeTransferFrom(address(vaults[uToken]), vault, balance);

        vaults[uToken] = IBinaryVault(vault);

        emit VaultMigrated(oldVault, vault, uToken);
    }

    function _addVault(address uToken, address vault, bool isMigrate) private {
        if (isMigrate) {
            _migrateVault(uToken, vault);
        } else {
            vaults[uToken] = IBinaryVault(vault);
            underlyingTokens.push(uToken);
        }
        emit NewVaultCreated(vault, uToken);
    }

    function migrateVault(address uToken, address vault) external onlyOwner {
        require(address(uToken) != address(0), "invalid underlying token");
        require(address(vault) != address(0), "invalid vault address");
        require(address(vaults[uToken]) != address(0), "not set");

        _migrateVault(uToken, vault);
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
