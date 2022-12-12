// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/binary/IBinaryVault.sol";
import "../interfaces/binary/IOracle.sol";
import "../interfaces/binary/IBinaryMarket.sol";
import "../interfaces/binary/IBinaryMarketManager.sol";
import "./BinaryMarket.sol";

// fixme why market doesn't have its contract address? We want to be able to deliver changes and have same manager. Otherwise it's not needed to have a manager at all
contract BinaryMarketManager is 
    Ownable, 
    IBinaryMarketManager 
{
    struct MarketData {
        address market;
        string pairName;
        bool enable;
    }

    MarketData[] public allMarkets;
    
    event MarketCreated(
        address indexed market, 
        address indexed creator, 
        address oracle, 
        address vault, 
        string name,
        string pairName,
        address admin,
        address operator,
        uint minBetAmount
    );

    constructor() Ownable() {}

    function createMarket(
        IOracle oracle_,
        IBinaryVault vault_,
        string memory marketName_,
        string memory pairName_,
        IBinaryMarket.TimeFrame[] memory timeframes_,
        address adminAddress_,
        address operatorAddress_,
        uint256 minBetAmount_
    ) external override  onlyOwner {

        BinaryMarket newMarket = new BinaryMarket(
            oracle_,
            vault_,
            marketName_,
            timeframes_,
            adminAddress_,
            operatorAddress_,
            minBetAmount_
        );

        allMarkets.push(
            MarketData(
                address(newMarket),
                pairName_,
                true
            )
        );

        emit MarketCreated(
            address(newMarket), 
            msg.sender, 
            address(oracle_),
            address(vault_),
            marketName_,
            pairName_,
            adminAddress_,
            operatorAddress_,
            minBetAmount_
        );
    }

    /// @dev Retrieve market by market pair name
    function getMarketByPairName(string memory pairName) external view returns(address) {
        for (uint256 i = 0; i < allMarkets.length; i = i + 1) {
            MarketData memory d = allMarkets[i];
            if (keccak256(abi.encodePacked(d.pairName)) == keccak256(abi.encodePacked(pairName))) {
                return d.market;
            }
        }
        return address(0);
    }
}
