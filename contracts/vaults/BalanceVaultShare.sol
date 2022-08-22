// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "erc721a-upgradeable/contracts/extensions/ERC721AQueryableUpgradeable.sol";

import "./BalanceVault.sol";
import "../utils/BokkyPooBahsDateTimeLibrary.sol";

    struct AmountInfo {
        uint[] amounts;
        address[] tokens;
        string ownerName;
        string ownerDescription;
        uint apr;
        uint roi;
        uint repaymentTimestamp;
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
    /// @param _ownerName name of vault
    /// @param _ownerDescription description of vault
    /// @param _apr given APR
    /// @param _roi given ROI
    /// @param _repaymentTimestamp repay timestamp
    /// @return tokenId of currently minted token
    function mint(
        address _user,
        uint[] calldata _amounts,
        address[] calldata _tokens,
        string calldata _ownerName,
        string calldata _ownerDescription,
        uint _apr,
        uint _roi,
        uint _repaymentTimestamp
    ) external returns (uint) {
        require(msg.sender == address(vault), "CALLER_NOT_VAULT");
        require(_user != address(0), "MISSING_USER");
        require(_tokens.length > 0, "MISSING_TOKENS");
        require(_tokens.length == _amounts.length, "AMOUNT_LENGTH");

        uint tokenId = _nextTokenId();
        amountInfos[tokenId] = AmountInfo({
        amounts : _amounts,
        tokens : _tokens,
        ownerName: _ownerName,
        ownerDescription: _ownerDescription,
        apr : _apr,
        roi : _roi,
        repaymentTimestamp : _repaymentTimestamp
        });

        _mint(_user, 1);

        return tokenId;
    }

    function getAmountInfos(uint _tokenId) external view returns (uint[] memory, address[] memory) {
        return (amountInfos[_tokenId].amounts, amountInfos[_tokenId].tokens);
    }

    function getOwnerName(uint _tokenId) internal view returns (string memory) {
        string memory name = amountInfos[_tokenId].ownerName;
        return string(abi.encodePacked(name, " (Balance Vault)"));
    }

    function getOwnerDescription(uint _tokenId) internal view returns (string memory) {
        return amountInfos[_tokenId].ownerDescription;
    }

    function getRepayment(uint _tokenId) internal view returns (string memory) {
        uint timestamp = amountInfos[_tokenId].repaymentTimestamp;
        if (timestamp == 0) return "Undefined";

        uint year = BokkyPooBahsDateTimeLibrary.getYear(timestamp);
        uint month = BokkyPooBahsDateTimeLibrary.getMonth(timestamp);
        uint day = BokkyPooBahsDateTimeLibrary.getDay(timestamp);
        uint hour = BokkyPooBahsDateTimeLibrary.getHour(timestamp);
        uint minute = BokkyPooBahsDateTimeLibrary.getMinute(timestamp);
        return string(abi.encodePacked("Repayment: ", year, "/", month, "/", day, " ", hour, ":", minute));
    }

    function getApr(uint tokenId) internal view returns (string memory) {
        uint apr = amountInfos[tokenId].apr;
        if (apr == 0) return "Undefined";
        return string(abi.encodePacked("APR: ", (apr / 100), "%"));
    }

    function getRoi(uint tokenId) internal view returns (string memory) {
        uint roi = amountInfos[tokenId].roi;
        if (roi == 0) return "Undefined";
        return string(abi.encodePacked("ROI: ", (roi / 100), "%"));
    }

    function getTokenAmount(uint _tokenId, uint _index) internal view returns (string memory) {
        address[] memory tokens = amountInfos[_tokenId].tokens;
        uint[] memory amounts = amountInfos[_tokenId].amounts;

        if (tokens.length == 0 || _index >= tokens.length) return "Undefined";

        ERC20Upgradeable token = ERC20Upgradeable(tokens[_index]);
        uint amount = amounts[_index] / token.decimals();

        return string(abi.encodePacked("Deposited: ", amount, " ", token.symbol()));
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint tokenId) public view virtual override(IERC721AUpgradeable, ERC721AUpgradeable) returns (string memory) {
        uint length = amountInfos[tokenId].tokens.length + 9;

        uint index = 0;
        string[] memory parts = new string[](length);
        parts[index++] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="#1a2c38" /><text x="10" y="20" class="base">';
        parts[index++] = getOwnerName(tokenId);
        parts[index++] = '</text><text x="10" y="40" class="base">';
        parts[index++] = getRepayment(tokenId);
        parts[index++] = '</text><text x="10" y="40" class="base">';
        parts[index++] = getApr(tokenId);
        parts[index++] = '</text><text x="10" y="40" class="base">';
        parts[index++] = getRoi(tokenId);

        for (uint i = 0; i < amountInfos[tokenId].tokens.length; i++) {
            parts[index++] = '</text><text x="10" y="40" class="base">';
            parts[index++] = getTokenAmount(tokenId, i);
        }

        parts[index++] = "</text></svg>";

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]));

        index = 8;
        for (uint i = 0; i < amountInfos[tokenId].tokens.length; i++) {
            output = string(abi.encodePacked(output, parts[index++], parts[index++]));
        }
        output = string(abi.encodePacked(output, parts[index++]));

        string memory json = Base64Upgradeable.encode(
            bytes(
                string(
                    abi.encodePacked('{"name": ', '"', getOwnerName(tokenId), '- ', tokenId,
                        '", "description": "', getOwnerDescription(tokenId),'", "image": "data:image/svg+xml;base64,',
                        Base64Upgradeable.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(abi.encodePacked("data:application/json;base64,", json));

        return output;
    }

    function recoverTokens(IERC20Upgradeable token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}