// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IBinaryVault {
    event Staked(address user, uint256 tokenId, uint256 amount);

    event Unstaked(address user, uint256 amount);

    function underlyingToken() external view returns (IERC20Upgradeable);

    function whitelistedMarkets(address) external view returns (bool);

    function bet(address from, uint256 amount) external;

    function claim(address to, uint256 amount) external;

    function stake(address user, uint256 amount) external;

    function unstake(address user, uint256 amount) external;
}
