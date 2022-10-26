// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/binary/IOracle.sol";

contract OracleManager is Ownable {
    mapping(uint256 => IOracle) public oracles;

    event OracleAdded(uint256 indexed marketId, IOracle indexed oracle);

    function addOracle(uint256 marketId, address oracle) external onlyOwner {
        require(oracles[marketId] == address(0), "already added");
        require(oracle != address(0), "invalid oracle");

        oracles[marketId] = oracle;

        emit OracleAdded(marketId, oracle);
    }

    function getPrice(uint256 marketId, uint256 roundId)
        external
        view
        returns (uint256 timestamp, uint256 price)
    {
        (timestamp, price) = oracles[marketId].getPrice(roundId);
    }
}
