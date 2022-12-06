// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/binary/IBinaryVault.sol";
import "../interfaces/binary/IOracle.sol";
import "../interfaces/binary/IBinaryMarket.sol";
import "../interfaces/binary/IBinaryMarketManager.sol";
import "./BinaryMarket.sol";

contract BinaryMarketManager is 
    Ownable, 
    IBinaryMarketManager 
{
    struct MarketData {
        address market;
        bool enable;
    }

    MarketData[] public allMarkets;
    event MarketCreated(address indexed market, address indexed creator);

    constructor() Ownable() {}

    function createMarket(
        IOracle oracle_,
        IBinaryVault vault_,
        string memory marketName_,
        uint256 bufferBlocks_,
        IBinaryMarket.TimeFrame[] memory timeframes_,
        address adminAddress_,
        address operatorAddress_,
        uint256 minBetAmount_
    ) external override  onlyOwner {

        BinaryMarket newMarket = new BinaryMarket(
            oracle_,
            vault_,
            marketName_,
            bufferBlocks_,
            timeframes_,
            adminAddress_,
            operatorAddress_,
            minBetAmount_
        );

        allMarkets.push(
            MarketData(
                address(newMarket),
                true
            )
        );

        emit MarketCreated(address(newMarket), msg.sender);
    }
}