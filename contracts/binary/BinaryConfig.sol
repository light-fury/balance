// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./BinaryErrors.sol";
import "../interfaces/binary/IBinaryConfig.sol";

contract BinaryConfig is Ownable, IBinaryConfig {
    uint256 public constant FEE_BASE = 10_000;
    /// @dev Trading fee should be paid when winners claim their rewards, see claim function of Market
    uint256 public tradingFee;
    /// @dev Winners should claim their winning rewards within claim notice period
    uint256 public claimNoticePeriod;
    /// @dev treasury wallet
    address public treasury;

    constructor(
        uint16 tradingFee_,
        uint256 claimNoticePeriod_,
        address treasury_
    ) Ownable() {
        require(tradingFee_ < FEE_BASE, "Too high");
        require(treasury_ != address(0), "Invalid address");
        tradingFee = tradingFee_; // 10% as default
        claimNoticePeriod = claimNoticePeriod_;
        treasury = treasury_;
    }
    
    function setTradingFee(uint256 newTradingFee) external onlyOwner {
        require(newTradingFee < FEE_BASE, "Too high");
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
