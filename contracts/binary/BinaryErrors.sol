// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

// Common Errors
error ZERO_ADDRESS();
error ZERO_AMOUNT();

// Config Errors
error TOO_HIGH_FEE();

// Vault
error NOT_FROM_MARKET(address caller);
error NO_BETS_TO_CLAIM(address player, uint256 amount);
error EXPIRED_CLAIM(address player);
