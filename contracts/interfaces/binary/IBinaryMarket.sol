// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBinaryMarket {
    enum Position {
        Bull,
        Bear
    }
    
    struct TimeFrame {
        uint8 id;
        uint256 interval;
        uint256 intervalBlocks;
        uint256 bufferBlocks;
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
        uint256 price
    ) external;

    function getExecutableTimeframes() external view returns(string memory);
}
