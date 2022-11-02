// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBinaryVaultManager {
    function stake(address uToken, uint256 amount) external;

    function unstake(address uToken, uint256 amount) external;
}
