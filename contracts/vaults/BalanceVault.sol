// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./BalanceVaultManager.sol";
import "./BalanceVaultShare.sol";

/// @notice balance vault
contract BalanceVault is OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /// name of the vault owner
    string public ownerName;
    /// description of the vault owner
    string public ownerDescription;
    /// contact info of the vault owner
    string public ownerContactInfo;

    /// unmodifiable balance vault manager
    BalanceVaultManager public manager;
    /// unmodifiable balance share nft
    BalanceVaultShare public nft;
    /// unmodifiable wallet of the vault owner where all funds are going
    address public ownerWallet;
    /// unmodifiable funding amount with 18 decimals
    uint public fundingAmount;
    /// unmodifiable timestamp to freeze this fundraising
    uint public freezeTimestamp;
    /// unmodifiable timestamp to the payout of given APR
    uint public repaymentTimestamp;
    /// unmodifiable apr in 2 decimals
    uint public apr;

    address public USDB;
    uint public feeBorrower;
    uint public feeLenderUsdb;
    uint public feeLenderOther;

    /// unmodifiable allowed tokens which are 1:1 used for funding
    EnumerableSetUpgradeable.AddressSet internal allowedTokens;
    bool public frozen;
    bool public redeemPrepared;
    uint public toRepayAmount;

    ///
    /// events
    ///

    /// @notice info about user deposit
    /// @param _user caller
    /// @param _amount amount in token
    /// @param _token token CA
    /// @param _tokenId NFT token id minted
    event Deposited(address indexed _user, uint _amount, address _token, uint _tokenId);

    /// @notice info about premature withdraw of all user funds
    /// @param _user caller
    /// @param _amounts all amounts of all tokens
    /// @param _tokens CAs from all previous amounts
    /// @param _tokenIds NFT token ids burnt from given user
    event Withdrawed(address indexed _user, uint[] _amounts, address[] _tokens, uint[] _tokenIds);

    /// @notice vault frozen which means anyone cannot deposit or withdraw, users will wait until repayment
    /// @param _timestamp timestamp of frozen
    /// @param _amounts all amounts of fundraised funds
    /// @param _tokens all tokens of fundraised funds
    /// @param _toRepayAmount amount to repay
    /// @param _token in which token it should be paid
    event Frozen(uint _timestamp, uint[] _amounts, address[] _tokens, uint _toRepayAmount, address _token);

    ///
    ///
    ///

    /// @notice initialize newly created vault
    /// @param _params vault params
    function initialize(VaultParams memory _params) initializer public {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(_params.ownerInfos.length == 3, "INFOS_MISSING");

        ownerName = _params.ownerInfos[0];
        ownerDescription = _params.ownerInfos[1];
        ownerContactInfo = _params.ownerInfos[2];
        ownerWallet = _params.ownerWallet;

        manager = BalanceVaultManager(msg.sender);
        nft = BalanceVaultShare(_params.nftAddress);
        fundingAmount = _params.fundingAmount;

        for (uint i = 0; i < _params.allowedTokens.length; i++) {
            allowedTokens.add(_params.allowedTokens[i]);
        }

        freezeTimestamp = _params.freezeTimestamp;
        repaymentTimestamp = _params.repaymentTimestamp;
        apr = _params.apr;
        feeBorrower = _params.feeBorrower;
        feeLenderUsdb = _params.feeLenderUsdb;
        feeLenderOther = _params.feeLenderOther;
    }

    ///
    /// business logic
    ///

    /// @notice return of investment based on freeze timestamp and repayment timestamp
    function roi(uint _amount) public view returns (uint) {
        uint yieldSeconds = repaymentTimestamp - freezeTimestamp;
        return _amount * yieldSeconds * apr / 10000 / 31536000;
    }

    /// @notice get current fundraised amount
    /// @return _amounts amounts in _tokens tokens
    function fundraised() public view returns (uint[] memory _amounts, address[] memory _tokens) {
        uint[] memory amounts = new uint[](allowedTokens.length());
        address[] memory tokens = allowedTokens.values();

        for (uint i = 0; i < tokens.length; i++) {
            IERC20Upgradeable token = IERC20Upgradeable(tokens[i]);
            uint balance = token.balanceOf(address(this));
            amounts[i] = balance;
        }

        _amounts = amounts;
        _tokens = tokens;
    }

    /// @notice return all NFTs of given user
    /// @param _owner user
    /// @return all token ids of given user
    function tokensOfOwner(address _owner) public view returns (uint[] memory) {
        return nft.tokensOfOwner(_owner);
    }

    /// @notice get balances from all user NFTs
    /// @param _owner user
    /// @return _amounts all user balance and, _tokens all user tokens
    function balanceOf(address _owner) public view returns (uint[] memory _amounts, address[] memory _tokens) {
        uint[] memory tokenIds = tokensOfOwner(_owner);
        (_amounts, _tokens) = balanceOf(tokenIds);
    }

    /// @notice get balances from all user NFTs
    /// @param _tokenIds token ids which we want to count balance
    /// @return _amounts all user balance and _tokens all user tokens
    function balanceOf(uint[] memory _tokenIds) public view returns (uint[] memory _amounts, address[] memory _tokens) {
        if (_tokenIds.length == 0) {
            _amounts = new uint[](0);
            _tokens = new address[](0);
            return (_amounts, _tokens);
        }

        uint[] memory tmpAmounts = new uint[](0);
        address[] memory tmpTokens = new address[](0);
        for (uint i = 0; i < _tokenIds.length; i++) {
            (uint[] memory amounts, address[] memory tokens) = nft.getAmountInfos(_tokenIds[i]);

            for (uint j = 0; j < tokens.length; j++) {
                // FIXME performance
                tmpAmounts = withAmount(tmpAmounts, tmpTokens, amounts[j], tokens[j]);
                tmpTokens = withToken(tmpTokens, tokens[j]);
            }
        }

        (_amounts, _tokens) = unique(tmpAmounts, tmpTokens);
    }

    /// @notice deposit amount of given token into the vault
    /// @param _amount amount of token
    /// @param _token token ca
    /// @return _tokenId tokenId of currently minted nft
    function deposit(uint _amount, address _token) external nonReentrant returns (uint _tokenId) {
        require(allowedTokens.contains(_token), "TOKEN_NOT_WHITELISTED");
        require(block.timestamp < freezeTimestamp, "VAULT_FROZEN");
        IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // collect previous deposits
        uint[] memory tokenIds = tokensOfOwner(msg.sender);
        (uint[] memory amounts, address[] memory tokens) = balanceOf(tokenIds);

        // burn previous state
        for (uint i = 0; i < tokenIds.length; i++) {
            nft.burn(tokenIds[i]);
        }

        // mint new state
        amounts = withAmount(amounts, tokens, _amount, _token);
        tokens = withToken(tokens, _token);
        _tokenId = nft.mint(msg.sender, amounts, tokens);

        emit Deposited(msg.sender, _amount, _token, _tokenId);
    }


    /// @notice premature withdraw all your funds from vault, burn all your nfts without get any APR
    function withdraw() external nonReentrant {
        require(block.timestamp < freezeTimestamp, "VAULT_FROZEN");

        // collect previous deposits
        uint[] memory tokenIds = tokensOfOwner(msg.sender);
        (uint[] memory amounts, address[] memory tokens) = balanceOf(tokenIds);

        // burn previous state
        for (uint i = 0; i < tokenIds.length; i++) {
            nft.burn(tokenIds[i]);
        }

        // remember in history
        emit Withdrawed(msg.sender, amounts, tokens, tokenIds);

        // withdraw
        for (uint i = 0; i < tokens.length; i++) {
            IERC20Upgradeable(tokens[i]).safeTransfer(msg.sender, amounts[i]);
        }
    }

    /// @notice redeem all your NFTs for given APR in usdb
    function redeem() external nonReentrant {
        require(redeemPrepared, "REDEEM_FUNDS_NOT_PREPARED");

        uint[] memory tokenIds = tokensOfOwner(msg.sender);
        require(tokenIds.length > 0, "NFTS_NOT_FOUND");

        (uint[] memory amounts, address[] memory tokens) = balanceOf(tokenIds);
        uint toRepay = 0;
        uint fee = 0;
        for (uint i = 0; i < tokens.length; i++) {
            uint returnOfInvestment = roi(amounts[i]);
            toRepay += amounts[i] + returnOfInvestment;
            if (tokens[i] == manager.USDB()) {
                fee += returnOfInvestment * feeLenderUsdb / 10000;
            } else {
                fee += returnOfInvestment * feeLenderOther / 10000;
            }
        }

        require(toRepay <= toRepayAmount, "REPAY_OUT_OF_BOUNDS");
        IERC20Upgradeable(allowedTokens.values()[0]).safeTransfer(msg.sender, toRepay);
        IERC20Upgradeable(allowedTokens.values()[0]).safeTransfer(manager.DAO(), fee);
    }

    /// @notice return item index in array if exists, or uint max if not
    /// @param _array array can be empty
    /// @param _item item to search in array
    /// @param _arrayLength array length in case not filled array
    /// @return item index in array or uint max if not found
    function arrayIndex(address[] memory _array, address _item, uint _arrayLength) internal pure returns (uint) {
        require(_array.length >= _arrayLength, "ARR_LEN_TOO_BIG");

        for (uint i = 0; i < _arrayLength; i++) {
            if (_array[i] == _item) return i;
        }
        return type(uint).max;
    }

    /// @notice construct new array of tokens as a set
    /// @param _tokens tokens
    /// @param _token token to add to set
    /// @return new array of tokens as a set
    function withToken(address[] memory _tokens, address _token) internal pure returns (address[] memory) {
        uint index = arrayIndex(_tokens, _token, _tokens.length);

        // token not in the list
        if (index == type(uint).max) {
            address[] memory newTokens = new address[](_tokens.length + 1);
            newTokens[_tokens.length] = _token;
            return newTokens;
        }
        // token already in the list
        return _tokens;
    }

    /// @notice construct new array of amounts from set of tokens
    /// @param _amounts amounts which are in pair with tokens
    /// @param _tokens tokens
    /// @param _amount amount of token to add to amounts from set of tokens
    /// @param _token token to add to tokens set
    /// @return new array of amounts from set of tokens
    function withAmount(uint[] memory _amounts, address[] memory _tokens, uint _amount, address _token) internal pure returns (uint[] memory) {
        require(_amounts.length == _tokens.length, "ARRAY_LEN_NOT_MATCH");

        uint index = arrayIndex(_tokens, _token, _tokens.length);
        // token not in the list
        if (index == type(uint).max) {
            uint[] memory newAmounts = new uint[](_tokens.length + 1);
            newAmounts[_tokens.length] = _amount;
            return newAmounts;
        }

        // token already in the list
        _amounts[index] += _amount;
        return _amounts;
    }

    /// @notice creates new arrays of amounts and tokens from given amounts and tokens
    /// @param _amounts all amounts
    /// @param _tokens all tokens
    /// @return _newAmounts new amounts which are paired with _newTokens set, _newTokens set
    function unique(uint[] memory _amounts, address[] memory _tokens) internal pure returns (uint[] memory _newAmounts, address[] memory _newTokens) {
        require(_amounts.length == _tokens.length, "ARRAY_LEN_NOT_MATCH");
        if (_tokens.length == 1) return (_amounts, _tokens);

        uint realTokenCount = 0;
        uint[] memory tmpAmounts = new uint[](_tokens.length);
        address[] memory tmpTokens = new address[](_tokens.length);

        for (uint i = 0; i < _tokens.length; i++) {
            uint index = arrayIndex(tmpTokens, _tokens[i], realTokenCount);
            // token is not processed yet
            if (index == type(uint).max) {
                tmpAmounts[realTokenCount] = _amounts[i];
                tmpTokens[realTokenCount] = _tokens[i];
                realTokenCount++;
            }
            // token is already processed
            else {
                tmpAmounts[index] += _amounts[i];
            }
        }

        _newAmounts = new uint[](realTokenCount);
        _newTokens = new address[](realTokenCount);

        for (uint i = 0; i < realTokenCount; i++) {
            _newAmounts[i] = tmpAmounts[i];
            _newTokens[i] = tmpTokens[i];
        }

        return (_newAmounts, _newTokens);
    }

    ///
    /// management
    ///

    /// @notice change description of existing vault, should not harm existing users
    /// @param _ownerName name of the vault owner
    /// @param _ownerDescription description of vault purpose
    /// @param _ownerContactInfo contact info of vault owner
    function changeDescription(
        string calldata _ownerName,
        string calldata _ownerDescription,
        string calldata _ownerContactInfo
    ) external onlyOwner {
        require(!frozen, "ALREADY_FROZEN");

        ownerName = _ownerName;
        ownerDescription = _ownerDescription;
        ownerContactInfo = _ownerContactInfo;
    }

    /// @notice freeze vault, send fundraised funds into owners wallet, subtracted from vault fee
    function freeze() external nonReentrant onlyOwner {
        require(!frozen, "ALREADY_FROZEN");
        require(block.timestamp >= freezeTimestamp, "CANNOT_FREEZE_BEFORE_DEADLINE");

        frozen = true;

        uint[] memory amounts = new uint[](allowedTokens.length());
        address[] memory tokens = allowedTokens.values();

        uint totalAmount = 0;

        for (uint i = 0; i < tokens.length; i++) {
            IERC20Upgradeable token = IERC20Upgradeable(tokens[i]);
            uint balance = token.balanceOf(address(this));
            amounts[i] = balance;
            totalAmount += balance;

            uint yield = roi(balance);
            if (address(token) == manager.USDB()) {
                totalAmount += yield + yield * feeLenderUsdb / 10000;
            } else {
                totalAmount += yield + yield * feeLenderOther / 10000;
            }

            if (balance > 0) {
                uint toDao = balance * feeBorrower / 10000;
                uint toVaultOwner = balance - toDao;
                token.safeTransfer(ownerWallet, toVaultOwner);
                token.safeTransfer(manager.DAO(), toDao);
            }
        }

        toRepayAmount = totalAmount;

        emit Frozen(block.timestamp, amounts, tokens, toRepayAmount, tokens[0]);
    }

    /// @notice send all funds for redeem
    /// can be called before redeem timestamp
    function depositForRedeem() external nonReentrant onlyOwner {
        require(frozen, "NOT_FROZEN");
        require(!redeemPrepared, "REDEEM_ALREADY_PREPARED");

        IERC20Upgradeable(allowedTokens.values()[0]).safeTransferFrom(msg.sender, address(this), toRepayAmount);

        redeemPrepared = true;
    }

    function recoverTokens(IERC20Upgradeable token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}