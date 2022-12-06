// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBinaryVaultManager {
    function createNewVault(
        string memory name_,
        string memory symbol_,
        uint256 vaultId_,
        address underlyingToken_,
        address config_
    ) external;

    function stake(address uToken, uint256 amount) external;

    function unstake(address uToken, uint256 amount) external;
}
