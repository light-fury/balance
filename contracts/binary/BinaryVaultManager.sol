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

    event NewVaultCreated(
        address indexed vault, 
        address indexed underlyingToken,
        string name,
        string symbol,
        uint256 vaultId,
        address config,
        address owner
    );

    function createNewVault(
        string memory name_,
        string memory symbol_,
        uint256 vaultId_,
        address underlyingToken_,
        address config_
    ) external onlyOwner {
        require(address(underlyingToken_) != address(0), "invalid underlying token");
        require(address(vaults[underlyingToken_]) == address(0), "already set");

        IBinaryVault _newVault = new BinaryVault(
            name_,
            symbol_,
            vaultId_,
            underlyingToken_,
            config_,
            msg.sender
        );

        _addVault(underlyingToken_, address(_newVault));
        
        emit NewVaultCreated(
            address(_newVault), 
            underlyingToken_,
            name_,
            symbol_,
            vaultId_,
            config_,
            msg.sender
        );
    }

    function _addVault(address uToken, address vault) private {
        vaults[uToken] = IBinaryVault(vault);
        underlyingTokens.push(uToken);
    }
}
