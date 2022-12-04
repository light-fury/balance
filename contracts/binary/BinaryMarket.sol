// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/binary/IBinaryConfig.sol";
import "../interfaces/binary/IBinaryMarket.sol";
import "../interfaces/binary/IBinaryVault.sol";
import "../interfaces/binary/IOracle.sol";
import "./BinaryErrors.sol";

contract BinaryMarket is
    OwnableUpgradeable,
    PausableUpgradeable,
    IBinaryMarket
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Market Data
    string public marketName;
    IOracle public oracle;
    IBinaryVault public vault;
    IBinaryConfig public config;

    IERC20Upgradeable public underlyingToken;

    /// @dev Timeframes supported in this market.
    TimeFrame[] public timeframes;

    /// @dev Rounds per timeframe
    mapping(uint8 => mapping(uint256 => Round)) public rounds; // timeframe id => round id => round

    /// @dev bet info per user and round
    mapping(uint8 => mapping(uint256 => mapping(address => BetInfo)))
        public ledger; // timeframe id => round id => address => bet info

    // @dev user rounds per timeframe
    mapping(uint8 => mapping(address => uint256[])) public userRounds; // timeframe id => user address => round ids

    /// @dev current round id per timeframe.
    mapping(uint8 => uint256) public currentEpochs; // timeframe id => current round id

    /// @dev This should be modified
    uint256 public minBetAmount;
    uint256 public bufferBlocks;
    uint256 public oracleLatestRoundId;

    address public adminAddress;
    address public operatorAddress;

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "operator: wut?");
        _;
    }

    modifier onlyAdminOrOperator() {
        require(
            msg.sender == adminAddress || msg.sender == operatorAddress,
            "admin | operator: wut?"
        );
        _;
    }

    function initialize(
        IOracle oracle_,
        IBinaryVault vault_,
        IBinaryConfig config_,
        string memory marketName_,
        uint256 _bufferBlocks,
        TimeFrame[] memory timeframes_,
        address adminAddress_,
        address operatorAddress_
    ) external initializer {
        if (address(oracle_) == address(0)) revert ZERO_ADDRESS();
        if (address(vault_) == address(0)) revert ZERO_ADDRESS();
        if (address(config_) == address(0)) revert ZERO_ADDRESS();
        if (timeframes_.length == 0) revert INVALID_TIMEFRAMES();

        __Ownable_init();

        oracle = oracle_;
        vault = vault_;
        config = config_;
        bufferBlocks = _bufferBlocks;

        marketName = marketName_;
        adminAddress = adminAddress_;
        operatorAddress = operatorAddress_;

        for (uint8 i = 0; i < timeframes_.length; i = i + 1) {
            timeframes.push(timeframes_[i]);
        }

        underlyingToken = vault.underlyingToken();
    }

    /**
     * @notice Set oracle of underlying token of this market
     * @dev Only owner can set the oracle
     * @param oracle_ New oracle address to set
     */
    function setOracle(IOracle oracle_) external onlyOwner {
        if (address(oracle_) == address(0)) revert ZERO_ADDRESS();
        oracle = oracle_;
    }

    /**
     * @dev Get latest recorded price from oracle
     * If it falls below allowed buffer or has not updated, it would be invalid
     */
    function _getPriceFromOracle() internal returns (uint256, uint256, uint256) {
        (uint256 roundId, uint256 price, uint256 timestamp) = oracle.latestRoundData();
       
        require(
            roundId > oracleLatestRoundId,
            "Oracle update roundId must be larger than oracleLatestRoundId"
        );
        oracleLatestRoundId = roundId;
        return (roundId, price, timestamp);
    }

    function _writeOraclePrice(uint256 timestamp, uint256 price) internal {
        (uint256 currentRoundId, , uint256 currentTimestamp  ) = _getPriceFromOracle();
        require(timestamp > currentTimestamp, "Invalid timestamp");
        oracle.writePrice(currentRoundId + 1, timestamp, price);
    }

    /**
     * @dev Start the next round n, lock price for round n-1, end round n-2
     */
    function executeRound(
        uint8[] memory timeframeIds,
        uint256 price,
        uint256 timestamp
    ) external onlyOperator whenNotPaused {
        // Update oracle price
        _writeOraclePrice(timestamp, price);

        (uint256 currentRoundId, uint256 currentPrice, ) = _getPriceFromOracle();

        for (uint8 i = 0; i < timeframeIds.length; i = i + 1) {
            uint8 timeframeId = timeframeIds[i];
            uint256 currentEpoch = currentEpochs[timeframeId];
            // CurrentEpoch refers to previous round (n-1)
            _safeLockRound(
                timeframeId,
                currentEpoch,
                currentRoundId,
                currentPrice
            );
            _safeEndRound(
                timeframeId,
                currentEpoch - 1,
                currentRoundId,
                currentPrice
            );

            // Increment currentEpoch to current round (n)
            currentEpoch = currentEpoch + 1;
            currentEpochs[timeframeId] = currentEpoch;
            _safeStartRound(timeframeId, currentEpoch);
        }
    }

    /**
     * @dev Start round
     * Previous round n-2 must end
     */
    function _safeStartRound(uint8 timeframeId, uint256 epoch) internal {
        require(
            rounds[timeframeId][epoch - 2].closeBlock != 0,
            "Can only start round after round n-2 has ended"
        );
        require(
            block.number >= rounds[timeframeId][epoch - 2].closeBlock,
            "Can only start new round after round n-2 closeBlock"
        );
        _startRound(timeframeId, epoch);
    }

    function _startRound(uint8 timeframeId, uint256 epoch) internal {
        Round storage round = rounds[timeframeId][epoch];
        round.startBlock = block.number;
        round.lockBlock = block.number + timeframes[timeframeId].intervalBlocks;
        round.closeBlock = block.number + timeframes[timeframeId].intervalBlocks * 2;
        round.epoch = epoch;
        round.totalAmount = 0;

        emit StartRound(timeframeId, epoch);
    }

    /**
     * @dev Lock round
     */
    function _safeLockRound(
        uint8 timeframeId,
        uint256 epoch,
        uint256 roundId,
        uint256 price
    ) internal {
        require(
            rounds[timeframeId][epoch].startBlock != 0,
            "Can only lock round after round has started"
        );
        require(
            block.number >= rounds[timeframeId][epoch].lockBlock,
            "Can only lock round after lockBlock"
        );
        require(
            block.number <= rounds[timeframeId][epoch].lockBlock + bufferBlocks,
            "Can only lock round within bufferBlocks"
        );
        _lockRound(timeframeId, epoch, roundId, price);
    }

    function _lockRound(
        uint8 timeframeId,
        uint256 epoch,
        uint256 roundId,
        uint256 price
    ) internal {
        Round storage round = rounds[timeframeId][epoch];
        round.lockPrice = price;
        round.lockOracleId = roundId;

        emit LockRound(timeframeId, epoch, roundId, round.lockPrice);
    }

    /**
     * @dev End round
     */
    function _safeEndRound(
        uint8 timeframeId,
        uint256 epoch,
        uint256 roundId,
        uint256 price
    ) internal {
        require(
            rounds[timeframeId][epoch].lockBlock != 0,
            "Can only end round after round has locked"
        );
        require(
            block.number >= rounds[timeframeId][epoch].closeBlock,
            "Can only end round after closeBlock"
        );
        require(
            block.number <=
                rounds[timeframeId][epoch].closeBlock + bufferBlocks,
            "Can only end round within bufferBlocks"
        );
        _endRound(timeframeId, epoch, roundId, price);
    }

    function _endRound(
        uint8 timeframeId,
        uint256 epoch,
        uint256 roundId,
        uint256 price
    ) internal {
        Round storage round = rounds[timeframeId][epoch];
        round.closePrice = price;
        round.closeOracleId = roundId;
        round.oracleCalled = true;

        emit EndRound(timeframeId, epoch, roundId, round.closePrice);
    }

    /**
     * @dev Bet bear position
     * @param amount Bet amount
     * @param timeframeId id of 1m/5m/10m
     * @param position bull/bear
     */
    function openPosition(
        uint256 amount,
        uint8 timeframeId,
        Position position
    ) external whenNotPaused {
        uint256 currentEpoch = currentEpochs[timeframeId];
        underlyingToken.safeTransferFrom(msg.sender, address(vault), amount);

        require(_bettable(timeframeId, currentEpoch), "Round not bettable");
        require(
            amount >= minBetAmount,
            "Bet amount must be greater than minBetAmount"
        );
        require(
            ledger[timeframeId][currentEpoch][msg.sender].amount == 0,
            "Can only bet once per round"
        );

        // Update round data
        Round storage round = rounds[timeframeId][currentEpoch];
        round.totalAmount = round.totalAmount + amount;
        
        if (position == Position.Bear) {
            round.bearAmount = round.bearAmount + amount;
        } else {
            round.bullAmount = round.bullAmount + amount;
        }

        // Update user data
        BetInfo storage betInfo = ledger[timeframeId][currentEpoch][msg.sender];
        betInfo.position = Position.Bear;
        betInfo.amount = amount;
        userRounds[timeframeId][msg.sender].push(currentEpoch);

        emit PositionOpened(
            marketName,
            msg.sender,
            amount,
            timeframeId,
            currentEpoch,
            position
        );
    }

    function _claim(uint8 timeframeId, uint256 epoch) internal {
        require(
            rounds[timeframeId][epoch].startBlock != 0,
            "Round has not started"
        );
        require(
            block.number > rounds[timeframeId][epoch].closeBlock,
            "Round has not ended"
        );
        require(
            !ledger[timeframeId][epoch][msg.sender].claimed,
            "Rewards claimed"
        );

        uint256 rewardAmount = 0;
        BetInfo storage betInfo = ledger[timeframeId][epoch][msg.sender];

        // Round valid, claim rewards
        if (rounds[timeframeId][epoch].oracleCalled) {
            require(
                isClaimable(timeframeId, epoch, msg.sender),
                "Not eligible for claim"
            );
            rewardAmount = betInfo.amount * 2;
        }
        // Round invalid, refund bet amount
        else {
            require(
                refundable(timeframeId, epoch, msg.sender),
                "Not eligible for refund"
            );

            rewardAmount = betInfo.amount;
        }

        betInfo.claimed = true;
        vault.claimBettingRewards(msg.sender, rewardAmount);

        emit Claimed(marketName, msg.sender, timeframeId, epoch, rewardAmount);
    }

    /**
     * @notice claim winning rewards
     * @param timeframeId Timeframe ID to claim winning rewards
     * @param epoch round id
     */
    function claim(uint8 timeframeId, uint256 epoch) external {
        _claim(timeframeId, epoch);
    }

    /**
     * @notice Batch claim winning rewards
     * @param timeframeIds Timeframe IDs to claim winning rewards
     * @param epochs round ids
     */
    function claimBatch(uint8[] memory timeframeIds, uint256[][] memory epochs) external {
        require(timeframeIds.length == epochs.length, "Invalid array length");

        for (uint256 i = 0; i < timeframeIds.length; i = i + 1) {
            uint8 timeframeId = timeframeIds[i];
            for (uint256 j = 0; j < epochs[i].length; j = j + 1) {
                _claim(timeframeId, epochs[i][j]);
            }
        }
    }

    /**
     * @dev Get the claimable stats of specific epoch and user account
     */
    function isClaimable(
        uint8 timeframeId,
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[timeframeId][epoch][user];
        Round memory round = rounds[timeframeId][epoch];
        if (round.lockPrice == round.closePrice) {
            return false;
        }
        return
            round.oracleCalled &&
            ((round.closePrice > round.lockPrice &&
                betInfo.position == Position.Bull) ||
                (round.closePrice < round.lockPrice &&
                    betInfo.position == Position.Bear));
    }

    /**
     * @dev Determine if a round is valid for receiving bets
     * Round must have started and locked
     * Current block must be within startBlock and closeBlock
     */
    function _bettable(uint8 timeframeId, uint256 epoch)
        internal
        view
        returns (bool)
    {
        return
            rounds[timeframeId][epoch].startBlock != 0 &&
            rounds[timeframeId][epoch].lockBlock != 0 &&
            block.number > rounds[timeframeId][epoch].startBlock &&
            block.number < rounds[timeframeId][epoch].lockBlock;
    }

    /**
     * @dev Get the refundable stats of specific epoch and user account
     */
    function refundable(
        uint8 timeframeId,
        uint256 epoch,
        address user
    ) public view returns (bool) {
        BetInfo memory betInfo = ledger[timeframeId][epoch][user];
        Round memory round = rounds[timeframeId][epoch];
        return
            !round.oracleCalled &&
            block.number > round.closeBlock + bufferBlocks &&
            betInfo.amount != 0;
    }
}
