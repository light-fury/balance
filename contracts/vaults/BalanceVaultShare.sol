// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "erc721a-upgradeable/contracts/extensions/ERC721AQueryableUpgradeable.sol";

import "./BalanceVault.sol";

    struct AmountInfo {
        uint[] amounts;
        address[] tokens;
    }

/// @notice Share of Balance Vault
contract BalanceVaultShare is ERC721AQueryableUpgradeable, OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    BalanceVault public vault;

    /// token amounts representation of user share in given vault
    mapping(uint => AmountInfo) internal amountInfos;

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
    function burn(uint _tokenId) external {
        require(msg.sender == address(vault), "CALLER_NOT_VAULT");

        delete amountInfos[_tokenId];
        _burn(_tokenId, true);
    }

    /// @notice mints recipe share to the user
    /// @param _user depositor
    /// @param _amounts amounts of tokens provided into vault
    /// @param _tokens tokens provided into vault
    /// @return tokenId of currently minted token
    function mint(address _user, uint[] calldata _amounts, address[] calldata _tokens) external returns (uint) {
        require(msg.sender == address(vault), "CALLER_NOT_VAULT");
        require(_user != address(0), "MISSING_USER");
        require(_tokens.length > 0, "MISSING_TOKENS");
        require(_tokens.length == _amounts.length, "AMOUNT_LENGTH");

        uint tokenId = _nextTokenId();
        amountInfos[tokenId] = AmountInfo({
        amounts : _amounts,
        tokens : _tokens
        });

        _mint(_user, 1);

        return tokenId;
    }

    function getAmountInfos(uint _tokenId) external view returns (uint[] memory, address[] memory) {
        return (amountInfos[_tokenId].amounts, amountInfos[_tokenId].tokens);
    }

    function recoverTokens(IERC20Upgradeable token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}