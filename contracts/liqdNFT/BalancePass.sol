// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.14;

import "./ERC721A.sol";
import "./ERC721APausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

abstract contract ERC721URIStorage is ERC721A {
    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) internal _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

abstract contract ERC721Enumerable is ERC721A, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721A)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < ERC721A.balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply()
        public
        view
        virtual
        override(IERC721Enumerable, ERC721A)
        returns (uint256)
    {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < ERC721Enumerable.totalSupply(),
            "ERC721Enumerable: global index out of bounds"
        );
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 tokenId,
        uint256 quantity
    ) internal virtual override {
        super._beforeTokenTransfers(from, to, tokenId, quantity);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721A.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
        private
    {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721A.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

contract BalancePass is
    ERC721A,
    ERC721URIStorage,
    ERC721APausable,
    ERC721Enumerable,
    Ownable
{
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;

    /* ================== EVENTS ========================== */
    event NftMinted(address indexed user, uint256 tokenId);

    /* ================== STATE VARIABLES ================== */

    Counters.Counter private _tokenIds;
    address public liqdNFTAddress;

    uint256 public _totalSupply;
    string public baseTokenURI;
    uint256 maxMint;

    bool public whitelistMintStatus;

    mapping(uint256 => uint256[][]) tokenTypeArray;
    mapping(uint256 => TokenType) tokenType;

    /* ================ STRUCTS ========================= */
    enum TokenType {
        SILVER,
        GOLD,
        PLATINUM
    }

    /* ================= INITIALIZATION =================== */
    /** 
     @notice Constructor for the Pass Nonfungible Token
     @param _maxMint  uint256 the max number of mints on this chain
     @param _baseTokenURI string token metadata URI
     */

    constructor(
        uint256 _maxMint,
        string memory _baseTokenURI,
        bool _whitelistMintStatus
    ) ERC721A("Balance Pass", "BALANCE-PASS") {
        maxMint = _maxMint;
        baseTokenURI = _baseTokenURI;
        whitelistMintStatus = _whitelistMintStatus;
    }

    /* ================ POLICY FUNCTIONS ================= */
    /** 
     @notice Set the baseTokenURI
    */
    /// @param _baseTokenURI to set
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    /// @notice pause NFT
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice unpause NFT
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
        @notice set Max mint for nft
        @param _max uint256
     */
    function setMaxMint(uint256 _max) external onlyOwner {
        maxMint = _max;
    }

    /**
        @notice set token types of token ID
        @param _tokenIdInfo uint256 2d array 
        @param _tokenType enum TokenType
        @param _tokenTypeSequence uint256
     */
    function setTokenType(
        uint256[][] memory _tokenIdInfo,
        TokenType _tokenType,
        uint256 _tokenTypeSequence
    ) external onlyOwner {
        tokenTypeArray[_tokenTypeSequence] = _tokenIdInfo;
        tokenType[_tokenTypeSequence] = _tokenType;
    }

    /**
        @notice set mintstatus  true: whitelistmint false: public mint
        @param status bool
     */
    function setWhitelistMintStatus(bool status) external onlyOwner {
        whitelistMintStatus = status;
    }

    /* =============== USER FUNCTIONS ==================== */

    /**
        @notice mint whitelist user
        @param _user address
        @return tokenId uint256
     */
    function mint_whitelist_gh56gui(address _user)
        external
        payable
        whenNotPaused
        returns (uint256)
    {
        require(whitelistMintStatus, "Not whitelist mint");
        require(_totalSupply + 1 <= maxMint, "BalancePass: Max limit reached");
        uint256 tokenId = _tokenIds.current();

        //mint pass nft
        _safeMint(_user, 1);

        _totalSupply = _totalSupply.add(1);
        setTokenURI(tokenId, tokenURI(tokenId));
        _tokenIds.increment();

        emit NftMinted(_user, tokenId);
        return tokenId;
    }

    /** 
        @notice mint whitelist user
        @param _user address
        @return tokenId uint256
     */
    function mint_public_gh56gui(address _user)
        external
        payable
        whenNotPaused
        returns (uint256)
    {
        require(!whitelistMintStatus, "WhiteList mint period");
        require(_totalSupply + 1 <= maxMint, "BalancePass: Max limit reached");
        uint256 tokenId = _tokenIds.current();

        //mint pass nft
        _safeMint(_user, 1);

        _totalSupply = _totalSupply.add(1);
        setTokenURI(tokenId, tokenURI(tokenId));
        _tokenIds.increment();

        emit NftMinted(_user, tokenId);
        return tokenId;
    }

    /* =============== VIEW FUNCTIONS ==================== */
    /// @notice Get the base URI
    function _baseURI() public view override returns (string memory) {
        return baseTokenURI;
    }

    /**
     @notice return tokenURI of specific token ID
     @param tokenId uint256
     @return // string
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A, ERC721URIStorage)
        returns (string memory)
    {
        string memory tokenURISuffix = string(
            abi.encodePacked(toString(tokenId), ".json")
        );
        string memory _tokenURI = string(
            abi.encodePacked(baseTokenURI, "/", tokenURISuffix)
        );
        return _tokenURI;
    }

    /**
        @notice return user's tokenIDS
        @param _owner address
        @return _tokensOfOwner uint256[]
     */
    function getTokenIds(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _tokensOfOwner = new uint256[](
            ERC721A.balanceOf(_owner)
        );

        for (uint256 i = 0; i < ERC721A.balanceOf(_owner); i++) {
            _tokensOfOwner[i] = ERC721Enumerable.tokenOfOwnerByIndex(_owner, i);
        }
        return (_tokensOfOwner);
    }

    /**
        @notice return tokenTypes based on tokenId
        @param _tokenId uint256
        @return // TokenType
     */
    function getTokenType(uint256 _tokenId) public view returns (TokenType) {
        for (uint256 i = 0; i < 3; i++) {
            uint256[][] memory temp = tokenTypeArray[i];
            for (uint256 j = 0; j < temp.length; j++) {
                if (_tokenId >= temp[j][0] && _tokenId <= temp[j][1])
                    return tokenType[i];
            }
        }
    }

    /**
        @notice return totalSupply
     */
    function totalSupply()
        public
        view
        override(ERC721A, ERC721Enumerable)
        returns (uint256)
    {
        return _totalSupply;
    }

    /**
        @notice return interfaceID
        @param interfaceId bytes4
        @return // bool
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice current Token ID
    function currentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    /// @notice owner of NFT
    function ownerOfNftToken(uint256 tokenId) public view returns (address) {
        return ownerOf(tokenId);
    }

    /* =================== SUPPORT FUNCTION =================== */
    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
        Setting before Token transfers
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 tokenId,
        uint256 quantity
    )
        internal
        override(ERC721A, ERC721APausable, ERC721Enumerable)
        whenNotPaused
    {
        super._beforeTokenTransfers(from, to, tokenId, quantity);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721A, ERC721URIStorage)
    {
        super._burn(tokenId);
    }
}
