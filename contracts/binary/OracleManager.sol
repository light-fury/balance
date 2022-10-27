// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/binary/IOracle.sol";

contract OracleManager is Ownable {
    /// @dev marketId => oracle
    mapping(uint256 => address) public oracles;

    /// @dev Emit this event when adding a oracle
    event OracleAdded(uint256 indexed marketId, address indexed oracle);

    /**
     * @notice External function to add oracle
     * @dev This function is only permitted to the owner
     * @param marketId Market ID
     * @param oracle Oracle address
     */
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
        (timestamp, price) = IOracle(oracles[marketId]).getPrice(roundId);
    }
}
