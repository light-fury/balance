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

// FIXME tokenuri is failing when deposited
// FIXME weth deposits

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
    function initialize(
        address _vault
    ) initializerERC721A initializer public {
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
        _burn(_tokenId, false);
    }

    /// @notice mints recipe share to the user
    /// @param _user depositor
    /// @param _amounts amounts of tokens provided into vault
    /// @param _tokens tokens provided into vault
    /// @return tokenId of currently minted token
    function mint(
        address _user,
        uint[] calldata _amounts,
        address[] calldata _tokens
    ) external returns (uint) {
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

    function getOwnerName() internal view returns (string memory) {
        return string(abi.encodePacked(vault.ownerName(), " (Balance Vault)"));
    }

    function getOwnerDescription() internal view returns (string memory) {
        return vault.ownerDescription();
    }

    function getRepayment() internal view returns (string memory) {
        uint timestamp = vault.repaymentTimestamp();
        if (timestamp == 0) return "No repayment";

        string memory yearStr = StringsUpgradeable.toString(BokkyPooBahsDateTimeLibrary.getYear(timestamp));

        uint month = BokkyPooBahsDateTimeLibrary.getMonth(timestamp);
        string memory monthStr = StringsUpgradeable.toString(month);
        if (month < 10) {
            monthStr = string(abi.encodePacked("0", monthStr));
        }

        uint day = BokkyPooBahsDateTimeLibrary.getDay(timestamp);
        string memory dayStr = StringsUpgradeable.toString(day);
        if (day < 10) {
            dayStr = string(abi.encodePacked("0", dayStr));
        }

        uint hour = BokkyPooBahsDateTimeLibrary.getHour(timestamp);
        string memory hourStr = StringsUpgradeable.toString(hour);
        if (hour < 10) {
            hourStr = string(abi.encodePacked("0", hourStr));
        }

        uint minute = BokkyPooBahsDateTimeLibrary.getMinute(timestamp);
        string memory minuteStr = StringsUpgradeable.toString(minute);
        if (minute < 10) {
            minuteStr = string(abi.encodePacked("0", minuteStr));
        }

        return string(abi.encodePacked("Repayment: ", yearStr, "/", monthStr, "/", dayStr, " ", hourStr, ":", minuteStr));
    }

    function getApr() internal view returns (string memory) {
        uint apr = vault.apr();
        if (apr == 0) return "No APR";
        return string(abi.encodePacked("APR: ", StringsUpgradeable.toString(apr / 100), "%"));
    }

    function getRoi() internal view returns (string memory) {
        uint roi = vault.roi(1e9) * 10000 / 1e9;
        if (roi == 0) return "No ROI";
        return string(abi.encodePacked("ROI: ", StringsUpgradeable.toString(roi / 100), "%"));
    }

    function getTokenAmount(uint _tokenId, uint _index) public view returns (string memory) {
        uint[] memory amounts = amountInfos[_tokenId].amounts;
        address[] memory tokens = amountInfos[_tokenId].tokens;

        if (tokens.length == 0 || _index >= tokens.length) return "No deposits";

        ERC20Upgradeable token = ERC20Upgradeable(tokens[_index]);
        // FIXME weth decimals maybe show also last 2 digits
        uint amount = amounts[_index] / (10 ** token.decimals());

        return string(abi.encodePacked("Deposited: ", StringsUpgradeable.toString(amount), " ", token.symbol()));
    }

    /// @notice returns image in plain text
    /// @param _tokenId token id
    /// @return image for base64 encoding into manifest
    function getImagePlainText(uint _tokenId) public view returns (string memory) {
        uint length = /* 2x end/start text tag plus amount */ 2 * amountInfos[_tokenId].tokens.length + 9 /* 8 in header + 1 in footer */;

        string[] memory parts = new string[](length);
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 420 420"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="#1a2c38" /><text x="10" y="20" class="base">';
        parts[1] = getOwnerName();
        parts[2] = '</text><text x="10" y="40" class="base">';
        parts[3] = getRepayment();
        parts[4] = '</text><text x="10" y="60" class="base">';
        parts[5] = getApr();
        parts[6] = '</text><text x="10" y="80" class="base">';
        parts[7] = getRoi();

        // starts with 8
        uint index = 8;
        for (uint i = 0; i < amountInfos[_tokenId].tokens.length; i++) {
            parts[index] = string(abi.encodePacked('</text><text x="10" y="', StringsUpgradeable.toString(20 + 10 * index), '" class="base">'));
            parts[index+1] = getTokenAmount(_tokenId, i);
            index += 2;
        }

        parts[index] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]));

        index = 8 /* start of tokens */;
        for (uint i = 0; i < amountInfos[_tokenId].tokens.length; i++) {
            output = string(abi.encodePacked(output, parts[index], parts[index+1]));
            index += 2;
        }
        output = string(abi.encodePacked(output, parts[index]));
        return output;
    }

    /// @notice constructs manifest metadata in plaintext for base64 encoding
    /// @param _tokenId token id
    /// @return _manifest manifest for base64 encoding
    function getManifestPlainText(uint _tokenId) public view returns (string memory _manifest) {
        string memory image = getImagePlainText(_tokenId);

        _manifest = string(
            abi.encodePacked('{"name": ', '"', getOwnerName(), ' - ', StringsUpgradeable.toString(_tokenId),
            '", "description": "', getOwnerDescription(), '", "image": "data:image/svg+xml;base64,',
            Base64Upgradeable.encode(bytes(image)),
            '"}'
            )
        );
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint _tokenId) public view virtual override(IERC721AUpgradeable, ERC721AUpgradeable) returns (string memory) {
        string memory output = getManifestPlainText(_tokenId);
        string memory json = Base64Upgradeable.encode(bytes(output));
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function recoverTokens(IERC20Upgradeable token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}