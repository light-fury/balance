// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/binary/IBinaryMarket.sol";
import "../interfaces/binary/IBinaryVault.sol";
import "../interfaces/binary/IOracle.sol";
import "./BinaryErrors.sol";

// fixme I would personally get rid of roundid in oracle. Its redundant information. No need to have it in oracle and I would like if possible to switch oracle to chain link (to allow to write it like we can not that we will do it). That means we can use same oracle for perps. We want to configure perps from existing contracts we have. Less code we need to test and maintain.
// fixme decide if use error constants or error string, not both. Better to use "ERROR_LIKE_THIS" then "like this"
contract BinaryMarket is
    Pausable,
    IBinaryMarket
{
    using SafeERC20 for IERC20;

    // fixme do we real need all fields to be uint256?
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

    struct BetInfo {
        Position position;
        uint256 amount;
        bool claimed; // default false
    }

    /// @dev Market Data
    string public marketName;
    IOracle public oracle;
    IBinaryVault public vault;

    IERC20 public underlyingToken;

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
    uint256 public oracleLatestRoundId;

    // fixme why admin is not from ownable, why operator is not from accesscontrol?
    address public adminAddress;
    address public operatorAddress;

    bool public genesisStartOnce;

    event PositionOpened(
        string indexed marketName,
        address user,
        uint256 amount,
        uint8 timeframeId,
        uint256 roundId,
        Position position
    );

    event Claimed(
        string indexed marketName,
        address indexed user,
        uint8 timeframeId,
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

    event OracleChanged(
        address indexed oldOracle,
        address indexed newOracle
    );
    event VaultChanged(
        address indexed oldVault,
        address indexed newVault
    );
    event MarketNameChanged(
        string oldName,
        string newName
    );
    event AdminChanged(
        address indexed oldAdmin,
        address indexed newAdmin
    );
    event OperatorChanged(
        address indexed oldOperator,
        address indexed newOperator
    );


    // fixme move it to other fields. Above events
    /// @dev timeframe id => genesis locked?
    mapping(uint8 => bool) public genesisLockOnces;


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

    constructor(
        IOracle oracle_,
        IBinaryVault vault_,
        string memory marketName_,
        TimeFrame[] memory timeframes_,
        address adminAddress_,
        address operatorAddress_,
        uint256 minBetAmount_
    ) {
        if (address(oracle_) == address(0)) revert ZERO_ADDRESS();
        if (address(vault_) == address(0)) revert ZERO_ADDRESS();
        if (timeframes_.length == 0) revert INVALID_TIMEFRAMES();

        oracle = oracle_;
        vault = vault_;

        marketName = marketName_;
        adminAddress = adminAddress_;
        operatorAddress = operatorAddress_;
        minBetAmount = minBetAmount_;

        for (uint256 i = 0; i < timeframes_.length; i = i + 1) {
            timeframes.push(timeframes_[i]);
            // fixme no need to initialize false. It's by default . You are spending gas here
            genesisLockOnces[timeframes_[i].id] = false;
        }

        underlyingToken = vault.underlyingToken();
        // fixme false is default
        genesisStartOnce = false;
    }

    // fixme do we need to change vault and oracle at runtime? Wouldn't be better to deploy new market? I mean we should minimize way how contract owner can rug users. Maybe allow to change only oracle?

    /**
     * @notice Set oracle of underlying token of this market
     * @dev Only owner can set the oracle
     * @param oracle_ New oracle address to set
     */
    function setOracle(IOracle oracle_) external onlyAdmin {
        if (address(oracle_) == address(0)) revert ZERO_ADDRESS();
        emit OracleChanged(address(oracle), address(oracle_));
        oracle = oracle_;
    }

    /**
     * @notice Set vault of underlying token of this market
     * @dev Only owner can set the vault
     * @param vault_ New vault address to set
     */
    function setVault(IBinaryVault vault_) external onlyAdmin {
        if (address(vault_) == address(0)) revert ZERO_ADDRESS();
        emit VaultChanged(address(vault), address(vault_));
        vault = vault_;
    }

    /**
     * @notice Set name of this market
     * @dev Only owner can set name
     * @param name_ New name to set
     */
    function setName(string memory name_) external onlyAdmin {
        emit MarketNameChanged(marketName, name_);
        marketName = name_;
    }

    /**
     * @notice Set new admin of this market
     * @dev Only owner can set new admin
     * @param admin_ New admin to set
     */
    function setAdmin(address admin_) external onlyAdmin {
        require(admin_ != address(0), "Zero address");
        emit AdminChanged(adminAddress, admin_);
        adminAddress = admin_;
    }

    /**
     * @notice Set new operator of this market
     * @dev Only admin can set new operator
     * @param operator_ New operator to set
     */
    function setOperator(address operator_) external onlyAdmin {
        require(operator_ != address(0), "Zero address");
        emit OperatorChanged(operatorAddress, operator_);
        operatorAddress = operator_;
    }

    /**
     * @notice Set timeframes of this market
     * @dev Only admin can set new timeframe, format genesis
     * @param timeframes_ New timeframe to set
     */
    function setTimeframes(TimeFrame[] memory timeframes_) external onlyAdmin {
        require(timeframes_.length > 0, "Invalid length");
        genesisStartOnce = false;
        
        for (uint256 i = 0; i < timeframes_.length; i = i + 1) {
            timeframes.push(timeframes_[i]);
            genesisLockOnces[timeframes_[i].id] = false;
        }
        _unpause();
    }

    /**
     * @dev Get latest recorded price from oracle
     */
    function _getPriceFromOracle() internal returns (uint256, uint256, uint256) {
        (uint256 roundId, uint256 timestamp, uint256 price, ) = oracle.latestRoundData();
        require(
            roundId > oracleLatestRoundId,
            "Oracle update roundId must be larger than oracleLatestRoundId"
        );
        oracleLatestRoundId = roundId;
        return (roundId, price, timestamp);
    }

    function _writeOraclePrice(uint256 timestamp, uint256 price) internal {
        (uint256 roundId, , , ) = oracle.latestRoundData();
        oracle.writePrice(roundId + 1, timestamp, price);
    }

    /**
     * @dev Start genesis round
     */
    function genesisStartRound() external onlyOperator whenNotPaused {
        require(!genesisStartOnce, "Can only run genesisStartRound once");

        for (uint256 i = 0; i < timeframes.length; i = i + 1) {
            currentEpochs[timeframes[i].id] = currentEpochs[timeframes[i].id] + 1;
            _startRound(timeframes[i].id, currentEpochs[timeframes[i].id]);

        }
        genesisStartOnce = true;
    }

    /**
     * @dev Lock genesis round
     */
    function genesisLockRound(uint8 timeframeId) external onlyOperator whenNotPaused {
        require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
        require(!genesisLockOnces[timeframeId], "Can only run genesisLockRound once");
        
        oracle.writePrice(oracleLatestRoundId + 1, block.timestamp, 1 wei);

        (uint256 currentRoundId, uint256 currentPrice, ) = _getPriceFromOracle();

        _safeLockRound(timeframeId, currentEpochs[timeframeId], currentRoundId, currentPrice);
        currentEpochs[timeframeId] = currentEpochs[timeframeId] + 1;
        _startRound(timeframeId, currentEpochs[timeframeId]);
        genesisLockOnces[timeframeId] = true;
    }


    // fixme what if I have 2m and 3m timeframes? I would like to not depend on having 1m tf.
    /**
     * @dev Start the next round n, lock price for round n-1, end round n-2
     */
    function executeRound(
        uint8[] memory timeframeIds,
        uint256 price
    ) external onlyOperator whenNotPaused {
        require(
            genesisStartOnce,
            "Can only run after genesisStartRound is triggered"
        );
        uint256 timestamp = block.timestamp;
        // Update oracle price
        _writeOraclePrice(timestamp, price);

        (uint256 currentRoundId, uint256 currentPrice, ) = _getPriceFromOracle();

        for (uint8 i = 0; i < timeframeIds.length; i = i + 1) {
            uint8 timeframeId = timeframeIds[i];
            if(genesisLockOnces[timeframeId]) {

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
    }

    /**
     * @dev Start round
     * Previous round n-2 must end
     */
    function _safeStartRound(uint8 timeframeId, uint256 epoch) internal {
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
        betInfo.position = position;
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
        // fixme I cannot bet if it's locked
        // fixme here I want a safeguard that I cannot bet on such round which should have close price at time which already gone on block.timestamp 
        return
            rounds[timeframeId][epoch].startBlock != 0 &&
            rounds[timeframeId][epoch].lockBlock != 0 &&
            rounds[timeframeId][epoch].lockPrice == 0 &&
            block.number > rounds[timeframeId][epoch].startBlock;
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
            block.number > round.closeBlock &&
            betInfo.amount != 0;
    }

    /**
    * @dev Pause/unpause
    */

    function setPause(bool value) external onlyOperator {
        if (value) {
            _pause();
        } else {
            genesisStartOnce = false;
            for (uint i; i < timeframes.length; i = i + 1) {
                genesisLockOnces[timeframes[i].id] = false;
            }
            _unpause();
        }
    }

    
    /**
     * @dev set minBetAmount
     * callable by admin
     */
    function setMinBetAmount(uint256 _minBetAmount) external onlyAdmin {
        minBetAmount = _minBetAmount;
    }

    function isNecessaryToExecute(uint8 timeframeId) public view returns(bool) {
        if (!genesisLockOnces[timeframeId] || !genesisStartOnce) {
            return false;
        }

        uint256 currentEpoch = currentEpochs[timeframeId];
        Round memory round = rounds[timeframeId][currentEpoch];
        Round memory prevRound = rounds[timeframeId][currentEpoch - 1];

        bool lockable = round.startBlock != 0 && round.lockPrice == 0 && block.number >= round.lockBlock;
        bool closable = prevRound.lockBlock !=0 && prevRound.closePrice == 0 && !prevRound.oracleCalled && block.number >= prevRound.closeBlock;

        return lockable && closable && (prevRound.totalAmount > 0 || round.totalAmount > 0);
    }


    // fixme why this not returning array of uint8?
    /**
        @dev check if bet is active
     */

    function getExecutableTimeframes() external view returns(string memory) {
        string memory result = "";
        uint256 count = 0;

        for (uint256 i = 0; i < timeframes.length; i = i + 1) {
            uint8 timeframeId = timeframes[i].id;

            if (isNecessaryToExecute(timeframeId)) {
                if (count > 0) {
                    result = string.concat(",", result, Strings.toString(timeframeId));
                } else {
                    result = string.concat(result, Strings.toString(timeframeId));
                }
                count = count + 1;
            }
        }

        return result;
    }

    /**
     * @dev Return round epochs that a user has participated in specific timeframe
     */
    function getUserRounds(
        uint8 timeframeId,
        address user,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, uint256) {
        uint256 length = size;
        if (length > userRounds[timeframeId][user].length - cursor) {
            length = userRounds[timeframeId][user].length - cursor;
        }

        uint256[] memory values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = userRounds[timeframeId][user][cursor + i];
        }

        return (values, cursor + length);
    }
}
