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

library Hash {
    function hash(string calldata _string) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_string));
    }
}

contract OnChainBalancePassHolderStrategy is BalancePassHolderStrategy {

    BalancePassNft public balancePassNft;

    constructor(address _balancePassNft) {
        require(_balancePassNft != address(0));
        balancePassNft = BalancePassNft(_balancePassNft);
    }

    /// @notice return balance pass holder class
    /// @param _user user
    /// @return balance pass holder class, 'Undefined', 'Platinum', 'Silver', 'Gold'
    function getTokenType(address _user) external view returns (string memory) {
        uint[] memory tokens = balancePassNft.tokensOfOwner(_user);
        if (tokens.length == 0) return "Undefined";

        bool goldFound = false;
        bool silverFound = false;
        bool platinumFound = false;
        for (uint i = 0; i < tokens.length; i++) {
            string memory result = balancePassNft.getTokenType(tokens[i]);
            if (Hash.hash(result) == Hash.hash("Gold")) {
                goldFound = true;
                // we can skip as we found the best
                break;
            }
            else if (Hash.hash(result) == Hash.hash("Silver")) silverFound = true;
            else if (Hash.hash(result) == Hash.hash("Platinum")) platinumFound = true;
            // else undefined none of them found
        }

        if (goldFound) return "Gold";
        else if (silverFound) return "Silver";
        else if (platinumFound) return "Platinum";
        return "Undefined";
    }

}

contract OffChainBalancePassHolderStrategy is BalancePassHolderStrategy {

    /// mapping for user to list of tokenIds
    mapping(address => address[]) tokenIdSnapshot;
    /// unmodifiable mapping between tokenId and type
    mapping(address => string) tokenTypeSnapshot;

    /// @notice return balance pass holder class
    /// @param _user user
    /// @return balance pass holder class, 'Undefined', 'Platinum', 'Silver', 'Gold'
    function getTokenType(address _user) external view returns (string memory) {
        address[] memory tokens = tokenIdSnapshot[_user];
        if (tokens.length == 0) return "Undefined";

        bool goldFound = false;
        bool silverFound = false;
        bool platinumFound = false;
        for (uint i = 0; i < tokens.length; i++) {
            string memory result = tokenTypeSnapshot[tokens[i]];
            if (Hash.hash(result) == Hash.hash("Gold")) {
                goldFound = true;
                // we can skip as we found the best
                break;
            }
            else if (Hash.hash(result) == Hash.hash("Silver")) silverFound = true;
            else if (Hash.hash(result) == Hash.hash("Platinum")) platinumFound = true;
            // else undefined none of them found
        }

        if (goldFound) return "Gold";
        else if (silverFound) return "Silver";
        else if (platinumFound) return "Platinum";
        return "Undefined";
    }

    // FIXME add mappings

}

/// @notice Manages balance pass holders
contract BalancePassManager is Ownable {

    address private strategy;

    /// discount in percent with 2 decimals, 10000 is 100%
    uint public discountGold;
    /// discount in percent with 2 decimals, 10000 is 100%
    uint public discountSilver;
    /// discount in percent with 2 decimals, 10000 is 100%
    uint public discountPlatinum;

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
        if (Hash.hash(tokenType) == Hash.hash("Gold")) {
            amount = _fee * discountGold / 10000;
        } else if (Hash.hash(tokenType) == Hash.hash("Silver")) {
            amount = _fee * discountSilver / 10000;
        } else if (Hash.hash(tokenType) == Hash.hash("Platinum")) {
            amount = _fee * discountPlatinum / 10000;
        }

        uint realFee = _fee - amount;
        return (amount, realFee);
    }


    ///
    /// management
    ///

    function setStrategy(address _strategy) external onlyOwner {
        strategy = _strategy;
    }

    function setDiscountGold(uint _discountGold) external onlyOwner {
        require(_discountGold < 10000, "DISCOUNT_TOO_BIG");
        discountGold = _discountGold;
    }

    function setDiscountSilver(uint _discountSilver) external onlyOwner {
        require(discountSilver < 10000, "DISCOUNT_TOO_BIG");
        discountSilver = _discountSilver;
    }

    function setDiscountPlatinum(uint _discountPlatinum) external onlyOwner {
        require(discountPlatinum < 10000, "DISCOUNT_TOO_BIG");
        discountPlatinum = _discountPlatinum;
    }

}