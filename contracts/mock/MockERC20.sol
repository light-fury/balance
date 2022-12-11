// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MockERC20 is ERC20("Mock", "Mock") {
    constructor() {
        _mint(msg.sender, 1e50);
    }

    function mint(uint amount) external {
        _mint(msg.sender, amount);
    }
}
