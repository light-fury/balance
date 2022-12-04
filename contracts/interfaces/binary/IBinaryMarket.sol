// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBinaryMarket {
    struct Round {
        uint256 epoch;
        uint256 startBlock;
        uint256 lockBlock;
        uint256 closeBlock;
        uint256 lockPrice;
        uint256 closePrice;
        uint256 lockOracleId;
        uint256 closeOracleId;
        uint256 totalAmount;
        uint256 bullAmount;
        uint256 bearAmount;
        bool oracleCalled;
    }

    enum Position {
        Bull,
        Bear
    }

    struct BetInfo {
        Position position;
        uint256 amount;
        bool claimed; // default false
    }

    struct TimeFrame {
        uint8 id;
        uint256 interval;
        uint16 intervalBlocks;
    }

    function openPosition(
        uint256 amount,
        uint8 timeframe,
        Position position
    ) external;

    function claim(uint8 timeframeId, uint256 epoch) external;

    function claimBatch(uint8[] memory timeframeIds, uint256[][] memory epochs)
        external;

    function executeRound(
        uint8[] memory timeframeIds,
        uint256 price,
        uint256 timestamp
    ) external;

    event PositionOpened(
        string indexed marketName,
        address user,
        uint256 amount,
        uint256 timeframeId,
        uint256 roundId,
        Position position
    );

    event Claimed(
        string indexed marketName,
        address indexed user,
        uint256 timeframeId,
        uint256 indexed roundId,
        uint256 amount
    );

    event StartRound(uint8 indexed timeframeId, uint256 indexed epoch);
    event LockRound(
        uint8 indexed timeframeId,
        uint256 indexed epoch,
        uint256 indexed oracleRoundId,
        uint256 price
    );
    event EndRound(
        uint8 indexed timeframeId,
        uint256 indexed epoch,
        uint256 indexed oracleRoundId,
        uint256 price
    );
}
