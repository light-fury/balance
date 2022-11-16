// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

// Common Errors
error ZERO_ADDRESS();
error ZERO_AMOUNT();
error INPUT_ARRAY_MISMATCH();

// Config Errors
error TOO_HIGH_FEE();

// Oracle
error INVALID_ROUND(uint256 roundId);
error INVALID_ROUND_TIME(uint256 roundId, uint256 timestamp);
error NOT_ORACLE_WRITER(address sender);
error ORACLE_ALREADY_ADDED(uint256 marketId);

// Vault
error NOT_FROM_MARKET(address caller);
error NO_DEPOSIT(address user);
error EXCEED_BALANCE(address user, uint256 amount);
error EXCEED_BETS(address player, uint256 amount);
error EXPIRED_CLAIM(address player);
