// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

contract BalanceVaultShare is ERC721AUpgradeable, OwnableUpgradeable {

    // Take note of the initializer modifiers.
    // - `initializerERC721A` for `ERC721AUpgradeable`.
    // - `initializer` for OpenZeppelin's `OwnableUpgradeable`.
    function initialize() initializerERC721A initializer public {
        __ERC721A_init('BalanceVaultShare', 'BALANCE-VAULT-SHARE');
        __Ownable_init();
    }

    function mint(uint256 quantity) external payable {
        // `_mint`'s second argument now takes in a `quantity`, not a `tokenId`.
        _mint(msg.sender, quantity);
    }

    function adminMint(uint256 quantity) external payable onlyOwner {
        _mint(msg.sender, quantity);
    }
}