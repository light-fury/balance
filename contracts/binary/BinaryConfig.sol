// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./BinaryErrors.sol";
import "../interfaces/binary/IBinaryConfig.sol";

contract BinaryConfig is OwnableUpgradeable, IBinaryConfig {
    /// @dev Trading fee should be paid when winners claim their rewards, see claim function of Market
    uint256 public tradingFee; // 10000 base
    /// @dev Winners should claim their winning rewards within claim notice period
    uint256 public claimNoticePeriod;
    /// @dev treasury wallet
    address public treasury;

    function initialize() external initializer {
        __Ownable_init();

        tradingFee = 1000; // 10% as default
        claimNoticePeriod = 24 hours;
        treasury = msg.sender;
    }

    function setTradingFee(uint256 newTradingFee) external onlyOwner {
        if (newTradingFee > 10000) revert TOO_HIGH_FEE();
        tradingFee = newTradingFee;
    }

    function setClaimNoticePeriod(uint256 newNoticePeriod) external onlyOwner {
        claimNoticePeriod = newNoticePeriod;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZERO_ADDRESS();
        treasury = newTreasury;
    }
}
