// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IMarket {
    struct PositionInfo {
        address owner;
        bool direction;
        uint256 amount;
        uint256 timeframeId;
        uint256 roundId;
    }

    function openPosition(
        uint256 amount,
        uint256 timeframe,
        bool direction
    ) external;

    function claim(uint256 roundId) external;

    event PositionOpened(
        uint256 indexed marketId,
        address user,
        uint256 amount,
        uint256 timeframeId,
        bool direction,
        uint256 roundId
    );

    event Claimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 indexed positionId,
        uint256 amount
    );
}
