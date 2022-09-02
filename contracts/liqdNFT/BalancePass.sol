// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

/// Mint limits:
/// - there is limit 1 NFT per wallet
/// - using multiple wallets in same transaction through your SC is forbidden, so tx.origin should be direct msg.sender
/// - WL mint (and public mint if hard cap was not reached) will start at specific unix time of block
contract BalancePass is ERC721AQueryable, Ownable {

    using SafeERC20 for IERC20;

    string public baseTokenURI;

    uint public maxMint;
    uint public maxMintWalletLimit;
    uint public whitelistMintStartTimestamp;
    uint public publicMintStartTimestamp;
    bytes32 private whitelist1Root;
    bytes32 private whitelist2Root;
    mapping(address => uint8) public mintWalletLimit;

    mapping(uint8 => uint[][]) public tokenTypeArray;

    ///
    /// events
    ///

    event NftMinted(address indexed _user, uint _tokenId);

    /**
     @notice one time initialize for the Pass Nonfungible Token
     @param _maxMint  uint256 the max number of mints on this chain
        @param _maxMintWalletLimit  uint256 the max number of mints per wallet
        @param _baseTokenURI string token metadata URI
        @param _whitelistMintStatus boolean if the whitelist only is active
        @param _whitelist1Root bytes32 merkle root for whitelist
        @param _whitelist2Root bytes32 merkle root for whitelist
     */
    constructor(
        uint _maxMint,
        uint _maxMintWalletLimit,
        string memory _baseTokenURI,
        uint _whitelistMintStartTimestamp,
        uint _publicMintStartTimestamp,
        bytes32 _whitelist1Root,
        bytes32 _whitelist2Root
    ) ERC721A("Balance Pass", "BALANCE-PASS") {
        maxMint = _maxMint;
        maxMintWalletLimit = _maxMintWalletLimit;
        baseTokenURI = _baseTokenURI;
        whitelistMintStartTimestamp = _whitelistMintStartTimestamp;
        publicMintStartTimestamp = _publicMintStartTimestamp;
        whitelist1Root = _whitelist1Root;
        whitelist2Root = _whitelist2Root;
    }

    /// @notice set new metadata uri prefix
    /// @param _baseTokenURI new uri prefix (without /<tokenId>.json)
    function setBaseURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    /// @notice alter existing hard cap
    /// @param _maxMint new hard cap
    function setMaxMint(uint _maxMint) external onlyOwner {
        maxMint = _maxMint;
    }

    /// @notice change maximum allowed images per wallet
    /// @param _maxMintWalletLimit new limit
    function setMaxMintWalletLimit(uint _maxMintWalletLimit) external onlyOwner {
        maxMintWalletLimit = _maxMintWalletLimit;
    }

    /// @notice set unix timestamp when WL mint starts
    /// @param _whitelistMintStartTimestamp unix time in seconds
    function setWhitelistMintStartTimestamp(uint _whitelistMintStartTimestamp) external onlyOwner {
        whitelistMintStartTimestamp = _whitelistMintStartTimestamp;
    }

    /// @notice set unix timestamp when public mint starts
    /// @param _publicMintStartTimestamp unix time in seconds
    function setPublicMintStartTimestamp(uint _publicMintStartTimestamp) external onlyOwner {
        publicMintStartTimestamp = _publicMintStartTimestamp;
    }

    /**
        @notice set token types of token ID
        @param _tokenIdInfo uint256 2d array, example: [[1,10],[11,30]] which means 1 and 10 are in first interval and 11 and 30 are in second
        @param _tokenType uint8 0: Genesis 1: Gold 2: Platinum
     */
    function setTokenType(uint[][] memory _tokenIdInfo, uint8 _tokenType) external onlyOwner {
        tokenTypeArray[_tokenType] = _tokenIdInfo;
    }

    /**
        @notice set merkle root for initial whitelist
        @param _merkleroot bytes32 merkle root for primary whitelist
     */
    function setWhitelist1Root(bytes32 _merkleroot)
    external
    onlyOwner
    {
        whitelist1Root = _merkleroot;
    }

    /**
        @notice set merkle root for secondary whitelist
        @param _merkleroot bytes32 merkle root for primary whitelist
     */
    function setWhitelist2Root(bytes32 _merkleroot)
    external
    onlyOwner
    {
        whitelist2Root = _merkleroot;
    }

    /* =============== USER FUNCTIONS ==================== */


    /// @notice WL mint
    /// @param _merkleProof merkle proof array
    function mint_whitelist(bytes32[] calldata _merkleProof) external payable returns (uint) {
        require(block.timestamp >= whitelistMintStartTimestamp && block.timestamp <= publicMintStartTimestamp, "WHITELIST_MINT_DIDNT_START");

        // verify against merkle root
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, whitelist1Root, leaf), "BalancePass: Invalid proof");

        return doMint(true);
    }

    /// @notice public mint
    function mint_public() external payable returns (uint) {
        require(block.timestamp >= publicMintStartTimestamp, "PUBLIC_MINT_DIDNT_START");

        return doMint(true);
    }

    /// @notice owner mint
    function mint_owner() external payable onlyOwner returns (uint) {
        return doMint(false);
    }

    function doMint(bool _limitCheck) internal returns (uint) {
        require(totalSupply() < maxMint, "TOTAL_SUPPLY_REACHED");
        // this should mitigate to use multiple addresses in one transaction
        require(msg.sender == tx.origin, "SMART_CONTRACTS_FORBIDDEN");
        if (_limitCheck) {
            require(mintWalletLimit[msg.sender] + 1 <= maxMintWalletLimit, "MAX_WALLET_LIMIT_REACHED");
        }

        mintWalletLimit[msg.sender] += 1;

        uint tokenId = _nextTokenId();
        _mint(msg.sender, 1);

        emit NftMinted(msg.sender, tokenId);

        return tokenId;
    }

    /* =============== VIEW FUNCTIONS ==================== */
    /// @notice Get the base URI
    function baseURI() public view returns (string memory) {
        return baseTokenURI;
    }

    /// @notice return tokenURI of specific token ID
    /// @param _tokenId tokenid
    /// @return _tokenURI token uri
    function tokenURI(uint _tokenId) public view override(ERC721A, IERC721A) returns (string memory _tokenURI) {
        _tokenURI = string(abi.encodePacked(baseTokenURI, "/", Strings.toString(_tokenId), ".json"));
    }

    /// @notice current Token ID
    function currentTokenId() external view returns (uint256) {
        return _nextTokenId();
    }

    /**
        @notice return tokenTypes based on tokenId
        @param _tokenId uint256
        @return // string
     */
    function getTokenType(uint _tokenId) public view returns (string memory) {
        for (uint8 i = 0; i < 3; i++) {
            uint[][] memory temp = tokenTypeArray[i];
            for (uint j = 0; j < temp.length; j++) {
                if (_tokenId >= temp[j][0] && _tokenId <= temp[j][1])
                    if (i == 2) return "Platinum";
                    else if (i == 1) return "Gold";
                    else return "Genesis";
            }
        }
        return "Undefined";
    }

    /// @notice can recover tokens sent by mistake to this CA
    /// @param token CA
    function recoverTokens(IERC20 token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

}
