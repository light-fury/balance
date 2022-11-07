// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/binary/IMarket.sol";
import "../interfaces/binary/IOracle.sol";
import "../interfaces/binary/IBinaryVault.sol";

contract Market is OwnableUpgradeable, PausableUpgradeable, IMarket {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Market Data
    string public pairName;
    uint8 public version;
    uint256 public marketId;
    IOracle public oracle;
    IBinaryVault public vault;

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
        uint256 marketId_,
        string memory pairName_,
        uint8 version_,
        uint256[] calldata timeframes_
    ) external initializer {
        require(address(oracle_) != address(0), "invalid oracle");
        require(address(vault_) != address(0), "invalid vault");
        require(timeframes_.length > 0, "invalid timeframes");

        __Ownable_init();

        oracle = oracle_;
        vault = vault_;
        pairName = pairName_;
        version = version_;
        marketId = marketId_;
        timeframes = timeframes_;

        underlyingToken = vault.underlyingToken();
    }

    function setOracle(IOracle oracle_) external onlyOwner {
        require(address(oracle_) != address(0), "invalid oracle");
        oracle = oracle_;
    }

    function openPosition(
        uint256 amount,
        uint256 timeframeId,
        bool direction
    ) external {
        require(amount > 0, "zero amount");
        require(timeframeId < timeframes.length, "invalid timeframeId");

        underlyingToken.safeTransferFrom(msg.sender, address(vault), amount);

        uint256 nextRoundId = oracle.lastRoundId() + 1;
        require(
            positionsInRound[nextRoundId][msg.sender] == 0,
            "already created"
        );
        positions[msg.sender].push(
            PositionInfo({
                owner: msg.sender,
                direction: direction,
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

    function claim(uint256 roundId) external {
        uint256 positionId = positionsInRound[roundId][msg.sender];
        require(isClaimable(msg.sender, positionId), "you lose this round");

        PositionInfo memory pos = positions[msg.sender][positionId];
        vault.claim(pos.amount * 2, msg.sender);

        // TODO: maybe remove claimed position from the positions array

        emit Claimed(marketId, msg.sender, positionId, pos.amount);
    }

    function isClaimable(address user, uint256 positionId)
        public
        view
        returns (bool)
    {
        PositionInfo memory pos = positions[user][positionId];
        (uint256 timestamp, uint256 startingPrice) = oracle.getPrice(
            pos.roundId
        );
        // Should be claimable when the round is finished
        if (block.timestamp < timestamp + timeframes[pos.timeframeId]) {
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
