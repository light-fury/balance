// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IBinaryVault {
    function underlyingToken() external view returns (IERC20Upgradeable);

    function whitelistedMarkets(address) external view returns (bool);

    function claim(uint256 amount, address to) external;

    function stake(address user, uint256 amount) external;

    function unstake(address user, uint256 amount) external;
}
