// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

interface BalancePassNft {
    /**
     * @dev Returns an array of token IDs owned by `owner`.
     *
     * This function scans the ownership mapping and is O(`totalSupply`) in complexity.
     * It is meant to be called off-chain.
     *
     * See {ERC721AQueryable-tokensOfOwnerIn} for splitting the scan into
     * multiple smaller scans if the collection is large enough to cause
     * an out-of-gas error (10K collections should be fine).
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory);

    function getTokenType(uint256 _tokenId) external view returns (string memory);
}

interface BalancePassHolderStrategy {

    /// @notice return balance pass holder class
    /// @param _user user
    /// @return balance pass holder class, 'Undefined', 'Platinum', 'Silver', 'Gold'
    function getTokenType(address _user) external view returns (string memory);
}

contract OnChainBalancePassHolderStrategy is BalancePassHolderStrategy {

    BalancePassNft public balancePassNft;

    constructor(address _balancePassNft) {
        require(_balancePassNft != address(0));
        balancePassNft = BalancePassNft(_balancePassNft);
    }

    /// @notice return balance pass holder class
    /// @param _user user
    /// @return balance pass holder class, 'Undefined', 'Genesis', 'Gold', 'Platinum'
    function getTokenType(address _user) external view returns (string memory) {
        uint[] memory tokens = balancePassNft.tokensOfOwner(_user);
        if (tokens.length == 0) return "Undefined";

        bool platinumFound = false;
        bool goldFound = false;
        bool genesisFound = false;
        for (uint i = 0; i < tokens.length; i++) {
            string memory result = balancePassNft.getTokenType(tokens[i]);
            if (hash(result) == hash("Platinum")) {
                platinumFound = true;
                // we can skip as we found the best
                break;
            }
            else if (hash(result) == hash("Gold")) goldFound = true;
            else if (hash(result) == hash("Genesis")) genesisFound = true;
            // else undefined none of them found
        }

        if (platinumFound) return "Platinum";
        else if (goldFound) return "Gold";
        else if (genesisFound) return "Genesis";
        return "Undefined";
    }

    function hash(string memory _string) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_string));
    }

}

contract OffChainBalancePassHolderStrategy is BalancePassHolderStrategy, Ownable {

    address[] public users;
    /// mapping for user to list of tokenIds
    mapping(address => uint[]) public tokenIdSnapshot;
    /// unmodifiable mapping between tokenId and type
    mapping(uint8 => uint[][]) public tokenTypeArray;

    /// @notice return tokenTypes based on tokenId
    /// @param _tokenId uint256
    /// @return token type
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

    /// @notice set token types of token ID
    /// @param _tokenIdInfo uint256 2d array, example: [[1,10],[11,30]] which means 1 and 10 are in first interval and 11 and 30 are in second
    /// @param _tokenType uint8 0: Genesis 1: Gold 2: Platinum
    function setTokenType(uint[][] memory _tokenIdInfo, uint8 _tokenType) external onlyOwner {
        tokenTypeArray[_tokenType] = _tokenIdInfo;
    }

    /// @notice return balance pass holder class
    /// @param _user user
    /// @return balance pass holder class, 'Undefined', 'Genesis', 'Gold', 'Platinum'
    function getTokenType(address _user) external view returns (string memory) {
        uint[] memory tokens = tokenIdSnapshot[_user];
        if (tokens.length == 0) return "Undefined";

        bool platinumFound = false;
        bool goldFound = false;
        bool genesisFound = false;
        for (uint i = 0; i < tokens.length; i++) {
            string memory result = getTokenType(tokens[i]);
            if (hash(result) == hash("Platinum")) {
                platinumFound = true;
                // we can skip as we found the best
                break;
            }
            else if (hash(result) == hash("Gold")) goldFound = true;
            else if (hash(result) == hash("Genesis")) genesisFound = true;
            // else undefined none of them found
        }

        if (platinumFound) return "Platinum";
        else if (goldFound) return "Gold";
        else if (genesisFound) return "Genesis";
        return "Undefined";
    }

    function hash(string memory _string) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_string));
    }

    ///
    /// management
    ///

    function clearMappings() public onlyOwner {
        for (uint i = users.length - 1; i >= 0; i--) {
            address user = users[i];
            delete tokenIdSnapshot[user];
            users.pop();
        }
    }

    function addMapping(address _user, uint[] calldata _tokenIds) public onlyOwner {
        require(tokenIdSnapshot[_user].length == 0, "MAPPING_ALREADY_EXISTS");

        users.push(_user);
        tokenIdSnapshot[_user] = _tokenIds;
    }

    struct HolderSnapshot {
        address user;
        uint[] tokenIds;
    }

    function newMapping(HolderSnapshot[] calldata _holderSnapshots) external onlyOwner {
        clearMappings();

        for (uint i = 0; i < _holderSnapshots.length; i++) {
            addMapping(_holderSnapshots[i].user, _holderSnapshots[i].tokenIds);
        }
    }

}

/// @notice Manages balance pass holders
contract BalancePassManager is Ownable {

    address private strategy;

    /// discount in percent with 2 decimals, 10000 is 100%
    uint public discountPlatinum;
    /// discount in percent with 2 decimals, 10000 is 100%
    uint public discountGold;
    /// discount in percent with 2 decimals, 10000 is 100%
    uint public discountGenesis;

    ///
    /// business logic
    ///

    /// @notice get amount and fee part from fee
    /// @param _user given user
    /// @param _fee fee to split
    /// @return amount and fee part from given fee
    function getDiscountFromFee(address _user, uint _fee) external view returns (uint, uint) {
        if (strategy == address(0)) return (0, _fee);
        string memory tokenType = BalancePassHolderStrategy(strategy).getTokenType(_user);

        // Undefined
        uint amount = 0;
        if (hash(tokenType) == hash("Platinum")) {
            amount = _fee * discountPlatinum / 10000;
        } else if (hash(tokenType) == hash("Gold")) {
            amount = _fee * discountGold / 10000;
        } else if (hash(tokenType) == hash("Genesis")) {
            amount = _fee * discountGenesis / 10000;
        }

        uint realFee = _fee - amount;
        return (amount, realFee);
    }

    function hash(string memory _string) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_string));
    }

    ///
    /// management
    ///

    function setStrategy(address _strategy) external onlyOwner {
        strategy = _strategy;
    }

    function setDiscountPlatinum(uint _discountPlatinum) external onlyOwner {
        require(_discountPlatinum < 10000, "DISCOUNT_TOO_BIG");
        discountPlatinum = _discountPlatinum;
    }

    function setDiscountGold(uint _discountGold) external onlyOwner {
        require(_discountGold < 10000, "DISCOUNT_TOO_BIG");
        discountGold = _discountGold;
    }

    function setDiscountGenesis(uint _discountGenesis) external onlyOwner {
        require(_discountGenesis < 10000, "DISCOUNT_TOO_BIG");
        discountGenesis = _discountGenesis;
    }

}