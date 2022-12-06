// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBinaryVault {
    event Staked(address user, uint256 tokenId, uint256 amount);

    event Unstaked(address user, uint256 amount);

    event Betted(address user, uint256 amount);

    event Claimed(address user, uint256 amount);

    function underlyingToken() external view returns (IERC20);

    function whitelistedMarkets(address) external view returns (bool);

    function claimBettingRewards(address to, uint256 amount) external;

    function stake(address user, uint256 amount) external;

    function unstake(address user, uint256 amount) external;
}
