// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBinaryVault {
    function stake(address user, uint256 amount) external;

    function unstake(address user, uint256 amount) external;
}
