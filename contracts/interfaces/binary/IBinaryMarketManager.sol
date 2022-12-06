// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "./IOracle.sol";
import "./IBinaryVault.sol";
import "./IBinaryMarket.sol";

interface IBinaryMarketManager {
    function createMarket(
        IOracle oracle_,
        IBinaryVault vault_,
        string memory marketName_,
        uint256 _bufferBlocks,
        IBinaryMarket.TimeFrame[] memory timeframes_,
        address adminAddress_,
        address operatorAddress_,
        uint256 minBetAmount_
    ) external;
}