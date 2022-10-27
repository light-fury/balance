// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/binary/IOracle.sol";

contract Oracle is Ownable, IOracle {
    struct Round {
        address writer;
        uint256 time;
        uint256 price;
    }

    /// @dev Writer => whitelisted
    mapping(address => bool) public writers;

    /// @dev Prices by roundId
    mapping(uint256 => Round) public rounds;

    /// @dev Round ID of last round, Round ID is zero-based
    uint256 public lastRoundId;

    /// @dev Emit this event when updating writer status
    event WriterUpdated(address indexed writer, bool enabled);
    /// @dev Emit this event when writing a new price round
    event WrotePrice(
        address indexed writer,
        uint256 indexed roundId,
        uint256 indexed timestamp,
        uint256 price
    );

    modifier onlyWriter() {
        require(writers[msg.sender], "Oracle: not writer");
        _;
    }

    /**
     * @notice External function to enable/disable price writer
     * @dev This function is only permitted to the owner
     * @param writer Writter address to update
     * @param enable Boolean to enable/disable writer
     */
    function setWriter(address writer, bool enable) external onlyOwner {
        require(writer != address(0), "invalid writer");
        writers[writer] = enable;
        emit WriterUpdated(writer, enable);
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
            rounds[lastRoundId].writer == address(0) ||
                roundId == lastRoundId + 1,
            "invalid round"
        );
        require(
            timestamp > rounds[lastRoundId].time &&
                timestamp <= block.timestamp,
            "invalid time"
        );

        Round storage newRound = rounds[roundId];
        newRound.writer = msg.sender;
        newRound.price = price;
        newRound.time = timestamp;

        lastRoundId = roundId;

        emit WrotePrice(msg.sender, roundId, timestamp, price);
    }

    /**
     * @notice External function that records a new price round
     * @dev This function is only permitted to writters
     * @param roundId Round ID should be greater than last round id
     * @param timestamp Timestamp should be greater than last round's time, and less then current time.
     * @param price Price of round, based 1e18
     */
    function writePrice(
        uint256 roundId,
        uint256 timestamp,
        uint256 price
    ) external override onlyWriter {
        _writePrice(roundId, timestamp, price);
    }

    /**
     * @notice External function that records a new price round
     * @dev This function is only permitted to writters
     * @param roundIds Array of round ids
     * @param timestamps Array of timestamps
     * @param prices Array of prices
     */
    function writeBatchPrices(
        uint256[] memory roundIds,
        uint256[] memory timestamps,
        uint256[] memory prices
    ) external override onlyWriter {
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
        override
        returns (uint256 timestamp, uint256 price)
    {
        timestamp = rounds[roundId].time;
        price = rounds[roundId].price;
        require(timestamp != 0, "invalid round");
    }
}
