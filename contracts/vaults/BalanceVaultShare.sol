// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import "./BalanceVault.sol";

/// @notice Share of Balance Vault
contract BalanceVaultShare is ERC721AUpgradeable, OwnableUpgradeable {

    BalanceVault public vault;

    struct UserInfo {
        address[] tokens;
        uint[] amounts;
    }

    address[] tokens;
    mapping(uint => UserInfo) userInfos;

    /// @notice one time initialize
    /// @param _vault vault instance
    function initialize(address _vault) initializerERC721A initializer public {
        __ERC721A_init('BalanceVaultShare', 'BALANCE-VAULT-SHARE');
        __Ownable_init();

        require(_vault != address(0), "MISSING_VAULT");
        vault = BalanceVault(_vault);
    }

    /// @notice can burn user tokens in favor of creating new recipe token later from vault
    /// @param _tokenId tokenId to burn
    function burn(uint _tokenId) external onlyOwner {
        delete userInfos[_tokenId];
        _burn(_tokenId, true);
    }

    /// @notice mints recipe share to the user
    /// @param _user depositor
    /// @param _tokens tokens provided into vault
    /// @param _amounts amounts of tokens provided into vault
    function mint(address _user, address[] calldata _tokens, uint[] calldata _amounts) external onlyOwner {
        require(_user != address(0), "MISSING_USER");
        require(_tokens.length > 0, "MISSING_TOKENS");
        require(_tokens.length == _amounts.length, "AMOUNT_LENGTH");
        // FIXME require that tokens are used in vault

        UserInfo memory info = UserInfo({
            tokens: _tokens,
            amounts: _amounts
        });
        uint tokenId = _nextTokenId();
        userInfos[tokenId] = info;

        _mint(_user, 1);
    }
}