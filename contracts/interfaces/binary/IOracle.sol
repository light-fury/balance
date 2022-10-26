// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IOracle {
    function lastRoundId() external view returns (uint256);

    function writePrice(
        uint256 roundId,
        uint256 timestamp,
        uint256 price
    ) external;

    function writeBatchPrices(
        uint256[] memory roundIds,
        uint256[] memory timestamps,
        uint256[] memory prices
    ) external;

    function getPrice(uint256 roundId)
        external
        view
        returns (uint256 timestamp, uint256 price);
}
