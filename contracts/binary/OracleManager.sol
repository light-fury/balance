// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OracleManager is Ownable {
    mapping(uint256 => address) public oracles;

    event OracleAdded(uint256 indexed marketId, address indexed oracle);

    function addOracle(uint256 marketId, address oracle) external onlyOwner {
        require(oracles[marketId] == address(0), "already added");
        oracles[marketId] = oracle;

        emit OracleAdded(marketId, oracle);
    }
}
