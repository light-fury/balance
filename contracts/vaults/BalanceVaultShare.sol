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
        return vault.ownerName();
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
        uint tokenLength = amountInfos[_tokenId].tokens.length;
        uint length = /* rect+text for each token amount */ 2 * tokenLength + 12 /* 4 + 4 + 4 */;

        uint index = 0;
        string[] memory parts = new string[](length);
        parts[index++] = '<?xml version="1.0" encoding="UTF-8"?>';
        parts[index++] = '<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1359" viewBox="0 0 1080 1359">'
            '<style>.b,.h{fill:#fff;font-family:"Arial"}.h{font-size:83px}.b{font-size:34px;background-color:#000;padding:20px}</style>';
        parts[index++] = '<defs>'
            '<clipPath id="clip-path">'
                '<rect id="Rectangle_994" width="1080" height="1359" rx="34" stroke="#707070" stroke-width="1"/>'
            '</clipPath>'
            '<radialGradient id="radial-gradient" cx="0.5" cy="0.5" r="0.5" gradientUnits="objectBoundingBox">'
                '<stop offset="0" stop-color="#358077"/>'
                '<stop offset="1" stop-opacity="0"/>'
            '</radialGradient>'
            '<radialGradient id="radial-gradient-2" cx="0.5" cy="0.5" r="0.5" gradientUnits="objectBoundingBox">'
                '<stop offset="0" stop-color="#393493"/>'
                '<stop offset="1" stop-color="#1d1a4a" stop-opacity="0"/>'
            '</radialGradient>'
            '<linearGradient id="linear-gradient" y1="0.5" x2="1" y2="0.5" gradientUnits="objectBoundingBox">'
                '<stop offset="0" stop-color="#fff"/>'
                '<stop offset="1" stop-color="gray"/>'
            '</linearGradient>'
        '</defs>';
        parts[index++] = '<g id="Rectangle_993" stroke="#707070" stroke-width="1">'
            '<rect width="1080" height="1359" rx="34" stroke="none"/>'
            '<rect x="0.5" y="0.5" width="1079" height="1358" rx="33.5" fill="none"/>'
        '</g>'
        '<g id="Mask_Group_1" clip-path="url(#clip-path)">'
            '<g id="Group_12660" transform="translate(-1025 -1533.908)">'
                '<ellipse id="Ellipse_975" cx="1042" cy="1311.5" rx="1042" ry="1311.5" transform="translate(0 1963.908)" fill="url(#radial-gradient)"/>'
                '<ellipse id="Ellipse_976" cx="986" cy="1241" rx="986" ry="1241" transform="translate(1025 -0.092)" fill="url(#radial-gradient-2)"/>'
            '</g>'
        '</g>'
        '<g id="Rectangle_992" transform="translate(53 53)" fill="none" stroke="rgba(255,255,255,0.17)" stroke-width="1">'
            '<rect width="975" height="1254" rx="23" stroke="none"/>'
            '<rect x="0.5" y="0.5" width="974" height="1253" rx="22.5" fill="none"/>'
        '</g>'
        '<g id="Group_12556" transform="translate(-347.391 -267.524)">'
            '<g id="Group_12539" transform="translate(447.391 395.883)">'
                '<g id="Group_12544" transform="translate(0 0)">'
                    '<path id="Path_3381" d="M484.882-1143.461a51.172,51.172,0,0,1-39.349-39.349,8.723,8.723,0,0,1,8.509-10.564h0a8.655,8.655,0,0,1,8.5,6.835,33.7,33.7,0,0,0,26.067,26.068,8.655,8.655,0,0,1,6.835,8.5h0A8.724,8.724,0,0,1,484.882-1143.461Z" transform="translate(-412.268 1193.987)" fill="url(#linear-gradient)"/>'
                    '<path id="Path_3382" d="M379.928-1118.648a51.172,51.172,0,0,1,39.349,39.349,8.723,8.723,0,0,1-8.509,10.564h0a8.655,8.655,0,0,1-8.5-6.835,33.7,33.7,0,0,0-26.067-26.067,8.655,8.655,0,0,1-6.835-8.5h0A8.723,8.723,0,0,1,379.928-1118.648Z" transform="translate(-369.364 1151.897)" fill="url(#linear-gradient)"/>'
                    '<path id="Path_3383" d="M379.928-1144.869a51.171,51.171,0,0,0,39.349-39.349,8.723,8.723,0,0,0-8.509-10.563h0a8.655,8.655,0,0,0-8.5,6.835,33.7,33.7,0,0,1-26.067,26.067,8.654,8.654,0,0,0-6.835,8.5h0A8.723,8.723,0,0,0,379.928-1144.869Z" transform="translate(-369.364 1194.781)" fill="#fff"/>'
                    '<path id="Path_3384" d="M484.882-1118.648a51.172,51.172,0,0,0-39.349,39.349,8.723,8.723,0,0,0,8.509,10.564h0a8.655,8.655,0,0,0,8.5-6.835,33.7,33.7,0,0,1,26.067-26.067,8.656,8.656,0,0,0,6.835-8.5h0A8.723,8.723,0,0,0,484.882-1118.648Z" transform="translate(-412.268 1151.897)" fill="#fff"/>'
                '</g>'
            '</g>'
            '<text id="balance" transform="translate(645.958 450.121)" fill="#fff" stroke="rgba(0,0,0,0)" stroke-width="1" font-size="41" style="font-family:\'Arial\';" letter-spacing="0.05em"><tspan x="-87.801" y="0">balance</tspan></text>'
        '</g>';

        uint yStart = 763;
        for (uint i = 0; i < tokenLength; i++) {
            parts[index++] = string(abi.encodePacked('<rect width="585" height="104" rx="23" transform="translate(100 ', StringsUpgradeable.toString(yStart - i * 132), ')" fill="rgba(255,255,255,0.11)"/>'));
        }

        parts[index++] = '<rect width="585" height="104" rx="23" transform="translate(100 895)" fill="rgba(255,255,255,0.11)"/>';
        parts[index++] = '<rect width="211" height="104" rx="23" transform="translate(100 1025)" fill="rgba(255,255,255,0.11)"/>';
        parts[index++] = '<rect width="240" height="104" rx="23" transform="translate(100 1155)" fill="rgba(255,255,255,0.11)"/>';

        parts[index++] = string(abi.encodePacked('<text transform="translate(100 366)" class="h" style="font-family:\'Arial\';">', getOwnerName(), '</text>'));

        yStart = 827;
        for (uint i = 0; i < tokenLength; i++) {
            parts[index++] = string(abi.encodePacked('<text transform="translate(134 ', StringsUpgradeable.toString(yStart - i * 129), ')" class="b" style="font-family:\'Arial\';">', getTokenAmount(_tokenId, i), '</text>'));
        }

        parts[index++] = string(abi.encodePacked('<text transform="translate(134 956)" class="b" style="font-family:\'Arial\';">', getRepayment(), '</text>'));
        parts[index++] = string(abi.encodePacked('<text transform="translate(134 1085)" class="b" style="font-family:\'Arial\';">', getApr(), '</text>'));
        parts[index++] = string(abi.encodePacked('<text transform="translate(134 1219)" class="b" style="font-family:\'Arial\';">', getRoi(), '</text>'));
        parts[index] = '</svg>';

        // <xml> to <image>
        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3]));
        // <rect> for tokens
        for (uint i = 0; i < tokenLength; i++) {
            output = string(abi.encodePacked(output, parts[4 + i]));
        }
        // <rect> for others + <text> for heading
        output = string(abi.encodePacked(output, parts[4 + tokenLength], parts[5 + tokenLength], parts[6 + tokenLength], parts[7 + tokenLength]));
        // <text> for tokens
        for (uint i = 0; i < tokenLength; i++) {
            output = string(abi.encodePacked(output, parts[8 + tokenLength + i]));
        }
        // <text> for others + </svg>
        output = string(abi.encodePacked(output, parts[8 + 2 * tokenLength], parts[9 + 2 * tokenLength], parts[10 + 2 * tokenLength], parts[11 + 2 * tokenLength]));

        return output;
    }

    /// @notice constructs manifest metadata in plaintext for base64 encoding
    /// @param _tokenId token id
    /// @return _manifest manifest for base64 encoding
    function getManifestPlainText(uint _tokenId) public view returns (string memory _manifest) {
        string memory image = getImagePlainText(_tokenId);

        _manifest = string(
            abi.encodePacked('{"name": ', '"', getOwnerName(), ' (Balance Vault) - ', StringsUpgradeable.toString(_tokenId),
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