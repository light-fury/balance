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
    string public pairName;
    uint8 public version;
    uint256 public marketId;
    IOracle public oracle;
    IBinaryVault public vault;
    IBinaryConfig public config;

    IERC20Upgradeable public underlyingToken;
    /// @dev Timeframes supported in this market.
    uint256[] public timeframes;
    /// @dev Holding all positions indentified by owner address
    mapping(address => PositionInfo[]) public positions;
    /// @dev Holding all position ids identified by round id, roundId => owner => positionId
    mapping(uint256 => mapping(address => uint256)) private positionsInRound;

    function initialize(
        IOracle oracle_,
        IBinaryVault vault_,
        IBinaryConfig config_,
        uint256 marketId_,
        string memory pairName_,
        uint8 version_,
        uint256[] calldata timeframes_
    ) external initializer {
        if (address(oracle_) == address(0)) revert ZERO_ADDRESS();
        if (address(vault_) == address(0)) revert ZERO_ADDRESS();
        if (address(config_) == address(0)) revert ZERO_ADDRESS();
        if (timeframes_.length == 0) revert INVALID_TIMEFRAMES();

        __Ownable_init();

        oracle = oracle_;
        vault = vault_;
        config = config_;

        pairName = pairName_;
        version = version_;
        marketId = marketId_;
        timeframes = timeframes_;

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
     * @notice Open new position on the market for the next round
     * @param amount Amount of underlying tokens to bet
     * @param timeframeId timeframe window
     * @param direction Long or Short
     */
    function openPosition(
        uint256 amount,
        uint256 timeframeId,
        bool direction
    ) external {
        if (amount == 0) revert ZERO_AMOUNT();
        if (timeframeId >= timeframes.length)
            revert INVALID_TIMEFRAME_ID(timeframeId);

        underlyingToken.safeTransferFrom(msg.sender, address(vault), amount);

        uint256 nextRoundId = oracle.lastRoundId() + 1;
        if (positionsInRound[nextRoundId][msg.sender] != 0)
            revert POS_ALREADY_CREATED(nextRoundId, msg.sender);
        positions[msg.sender].push(
            PositionInfo({
                owner: msg.sender,
                direction: direction,
                claimed: false,
                amount: amount,
                timeframeId: timeframeId,
                roundId: nextRoundId
            })
        );

        uint256 positionId = positions[msg.sender].length;
        positionsInRound[nextRoundId][msg.sender] = positionId;

        emit PositionOpened(
            marketId,
            msg.sender,
            amount,
            timeframeId,
            direction,
            nextRoundId
        );
    }

    /**
     * @notice Claim winning rewards
     * @param roundId Round ID to claim winning rewards
     */
    function claim(uint256 roundId) external {
        uint256 positionId = positionsInRound[roundId][msg.sender];
        if (!isClaimable(msg.sender, positionId))
            revert CANNOT_CLAIM(roundId, msg.sender);

        PositionInfo storage pos = positions[msg.sender][positionId];
        pos.claimed = true;
        vault.claim(msg.sender, pos.amount * 2);

        emit Claimed(marketId, msg.sender, positionId, pos.amount);
    }

    /**
     * @notice Return claimability for given user and given round
     * @return claimability true or false
     */
    function isClaimable(
        address user,
        uint256 positionId
    ) public view returns (bool) {
        PositionInfo memory pos = positions[user][positionId];
        (uint256 timestamp, uint256 startingPrice) = oracle.getPrice(
            pos.roundId
        );
        // Should be claimable when the round is finished
        if (block.timestamp < timestamp + timeframes[pos.timeframeId]) {
            return false;
        }
        // Should be claimable within the claim notice period
        if (
            block.timestamp >
            timestamp + timeframes[pos.timeframeId] + config.claimNoticePeriod()
        ) {
            return false;
        }

        (, uint256 curPrice) = oracle.getPrice(pos.roundId + 1);
        if (pos.direction) {
            // LONG
            return curPrice > startingPrice;
        } else {
            // SHORT
            return curPrice < startingPrice;
        }
    }
}
