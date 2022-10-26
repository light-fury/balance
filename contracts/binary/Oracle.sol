// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Oracle is AccessControl {
    struct Round {
        address writer;
        uint256 time;
        uint256 price;
    }

    bytes32 public constant WRITER_ROLE = keccak256("WRITER");

    /// @dev Prices by roundId
    mapping(uint256 => Round) public rounds;

    /// @dev Round ID of last round, Round ID is zero-based
    uint256 public lastRoundId;

    /// @dev Emit this event when writing a new price round
    event WrotePrice(
        address indexed writer,
        uint256 indexed roundId,
        uint256 indexed timestamp,
        uint256 price
    );

    constructor() {
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(WRITER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice Internal function that records a new price round
     * @param roundId Round ID should be greater than last round id
     * @param timestamp Timestamp should be greater than last round's time, and less then current time.
     * @param price Price of round
     */
    function _writePrice(
        uint256 roundId,
        uint256 timestamp,
        uint256 price
    ) internal {
        require(
            lastRoundId == 0 || roundId == lastRoundId + 1,
            "invalid round"
        );
        require(
            timestamp >= rounds[roundId].time && timestamp <= block.timestamp,
            "invalid time"
        );

        Round storage newRound = rounds[roundId];
        newRound.price = price;
        newRound.time = timestamp;

        lastRoundId = roundId;

        emit WrotePrice(msg.sender, roundId, timestamp, price);
    }

    /**
     * @notice External function that records a new price round
     * @dev This function is only limited to WRITER_ROLE
     * @param roundId Round ID should be greater than last round id
     * @param timestamp Timestamp should be greater than last round's time, and less then current time.
     * @param price Price of round
     */
    function writePrice(
        uint256 roundId,
        uint256 timestamp,
        uint256 price
    ) external onlyRole(WRITER_ROLE) {
        _writePrice(roundId, timestamp, price);
    }

    /**
     * @notice External function that records a new price round
     * @dev This function is only limited to WRITER_ROLE
     * @param roundIds Array of round ids
     * @param timestamps Array of timestamps
     * @param prices Array of prices
     */
    function writeBatchPrices(
        uint256[] memory roundIds,
        uint256[] memory timestamps,
        uint256[] memory prices
    ) external onlyRole(WRITER_ROLE) {
        require(
            roundIds.length == timestamps.length &&
                roundIds.length == prices.length,
            "input array mismatch"
        );
        for (uint256 i = 0; i < roundIds.length; i++) {
            _writePrice(roundIds[i], timestamps[i], prices[i]);
        }
    }

    /**
     * @notice External function that returns the price and timestamp by round id
     * @param roundId Round ID to get
     * @return timestamp Round Time
     * @return price Round price
     */
    function getPrice(uint256 roundId)
        external
        view
        returns (uint256 timestamp, uint256 price)
    {
        timestamp = rounds[roundId].time;
        price = rounds[roundId].price;
        require(timestamp != 0, "invalid price");
    }
}
