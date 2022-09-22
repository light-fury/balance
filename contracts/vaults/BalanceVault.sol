// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./BalanceVaultManager.sol";
import "./BalanceVaultShare.sol";
import "../utils/ArrayUtils.sol";

struct VaultParams {
    string[] ownerInfos;
    string[] ownerContacts;
    address ownerWallet;
    address nftAddress;
    uint256 fundingAmount;
    address[] allowedTokens;
    uint256 freezeTimestamp;
    uint256 repaymentTimestamp;
    uint256 apr;
    uint256 feeBorrower;
    uint256 feeLenderUsdb;
    uint256 feeLenderOther;
}

/// @notice balance vault
contract BalanceVault is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for ERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /// name of the vault owner
    string public ownerName;
    /// description of the vault owner
    string public ownerDescription;
    /// contact info of the vault owner
    string[] public ownerContacts;

    /// unmodifiable balance vault manager
    BalanceVaultManager public manager;
    /// unmodifiable balance share nft
    BalanceVaultShare public nft;
    /// unmodifiable wallet of the vault owner where all funds are going
    address public ownerWallet;
    /// unmodifiable funding amount with 18 decimals
    uint256 public fundingAmount;
    /// (can be moved to the future but not above repaymentTimestamp) timestamp to freeze this fundraising
    uint256 public freezeTimestamp;
    /// unmodifiable timestamp to the payout of given APR
    uint256 public repaymentTimestamp;
    /// unmodifiable apr in 2 decimals
    uint256 public apr;

    uint256 public feeBorrower;
    uint256 public feeLenderUsdb;
    uint256 public feeLenderOther;

    /// unmodifiable allowed tokens which are 1:1 used for funding
    EnumerableSetUpgradeable.AddressSet internal allowedTokens;
    bool public frozen;
    bool public redeemPrepared;
    /// to repay amount in repay token (allowedTokens[0]) decimals
    uint256 public toRepayAmount;

    ///
    /// events
    ///

    /// @notice info about user deposit
    /// @param _user caller
    /// @param _amount amount in token
    /// @param _token token CA
    /// @param _tokenId NFT token id minted
    event Deposited(
        address indexed _user,
        uint256 _amount,
        address _token,
        uint256 _tokenId
    );

    /// @notice info about premature withdraw of all user funds
    /// @param _user caller
    /// @param _amounts all amounts of all tokens
    /// @param _tokens CAs from all previous amounts
    /// @param _tokenIds NFT token ids burnt from given user
    event Withdrawn(
        address indexed _user,
        uint256[] _amounts,
        address[] _tokens,
        uint256[] _tokenIds
    );

    /// @notice vault frozen which means anyone cannot deposit or withdraw, users will wait until repayment
    /// @param _timestamp timestamp of frozen
    /// @param _amounts all amounts of fundraised funds
    /// @param _tokens all tokens of fundraised funds
    /// @param _toRepayAmount amount to repay
    /// @param _token in which token it should be paid
    event Frozen(
        uint256 _timestamp,
        uint256[] _amounts,
        address[] _tokens,
        uint256 _toRepayAmount,
        address _token
    );

    /// @notice redeemed original deposit + yield
    /// @param _user calling user
    /// @param _tokenIds existing tokenIds
    /// @param _amount amount redeemed
    /// @param _fee fee sent to DAO
    /// @param _token in which token
    event Redeemed(
        address indexed _user,
        uint256[] _tokenIds,
        uint256 _amount,
        uint256 _fee,
        address _token
    );

    ///
    ///
    ///

    /// @notice initialize newly created vault
    /// @param _params vault params
    function initialize(VaultParams memory _params) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(_params.ownerInfos.length == 2, "INFOS_MISSING");

        ownerName = _params.ownerInfos[0];
        ownerDescription = _params.ownerInfos[1];
        ownerContacts = _params.ownerContacts;
        ownerWallet = _params.ownerWallet;

        manager = BalanceVaultManager(msg.sender);
        nft = BalanceVaultShare(_params.nftAddress);
        fundingAmount = _params.fundingAmount;

        for (uint256 i = 0; i < _params.allowedTokens.length; i++) {
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

    /// @notice ROI
    /// @param _amount amount with which its counted
    /// @return return of investment based on freeze timestamp and repayment timestamp
    function roi(uint256 _amount) public view returns (uint256) {
        uint256 yieldSeconds = repaymentTimestamp - freezeTimestamp;
        return (_amount * yieldSeconds * apr) / 10000 / 31536000;
    }

    /// @notice get current fundraised amount
    /// @return total amount fundraised summarized according to token decimals in 18 decimals
    function fundraised() public view returns (uint256) {
        uint256 totalFundraised = 0;

        address[] memory tokens = allowedTokens.values();
        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Upgradeable token = ERC20Upgradeable(tokens[i]);
            totalFundraised +=
                token.balanceOf(address(this)) *
                10**(18 - token.decimals());
        }

        return totalFundraised;
    }

    /// @notice get address of repay token
    /// @return repay token address
    function repayToken() public view returns (address) {
        return allowedTokens.values()[0];
    }

    /// @notice get all allowed tokens
    /// @return all all allowed tokens
    function getAllowedTokens() external view returns (address[] memory) {
        return allowedTokens.values();
    }

    function getOwnerContacts() external view returns (string[] memory) {
        return ownerContacts;
    }

    /// @notice return all NFTs of given user
    /// @param _owner user
    /// @return all token ids of given user
    function tokensOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        return nft.tokensOfOwner(_owner);
    }

    /// @notice get balances from all user NFTs
    /// @param _owner user
    /// @return _amounts all user balance in tokens decimals and, _tokens all user tokens
    function balanceOf(address _owner)
        public
        view
        returns (uint256[] memory _amounts, address[] memory _tokens)
    {
        uint256[] memory tokenIds = tokensOfOwner(_owner);
        (_amounts, _tokens) = balanceOf(tokenIds);
    }

    /// @notice get balances from all user NFTs
    /// @param _tokenIds token ids which we want to count balance
    /// @return _amounts all user balance in token decimals and _tokens all user tokens
    function balanceOf(uint256[] memory _tokenIds)
        public
        view
        returns (uint256[] memory _amounts, address[] memory _tokens)
    {
        if (_tokenIds.length == 0) {
            _amounts = new uint256[](0);
            _tokens = new address[](0);
            return (_amounts, _tokens);
        }

        uint256[] memory tmpAmounts;
        address[] memory tmpTokens;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            (uint256[] memory amounts, address[] memory tokens) = nft
                .getAmountInfos(_tokenIds[i]);

            for (uint256 j = 0; j < tokens.length; j++) {
                // FIXME performance
                tmpAmounts = withAmount(
                    tmpAmounts,
                    tmpTokens,
                    amounts[j],
                    tokens[j]
                );
                tmpTokens = withToken(tmpTokens, tokens[j]);
            }
        }

        (_amounts, _tokens) = unique(tmpAmounts, tmpTokens);
    }

    /// @return true if timestamp > freezeTimestamp or hard cap was reached
    function shouldBeFrozen() public view returns (bool) {
        return
            block.timestamp > freezeTimestamp || fundraised() == fundingAmount;
    }

    /// @notice deposit amount of given token into the vault
    /// @param _amount amount of token
    /// @param _token token ca
    /// @return _tokenId tokenId of currently minted nft
    function deposit(uint256 _amount, address _token)
        external
        nonReentrant
        returns (uint256 _tokenId)
    {
        require(allowedTokens.contains(_token), "TOKEN_NOT_WHITELISTED");
        require(!shouldBeFrozen(), "SHOULD_BE_FROZEN");

        uint256 remaining = fundingAmount - fundraised();
        uint256 remainingSameUnits = remaining /
            10**(18 - ERC20Upgradeable(_token).decimals());
        require(_amount <= remainingSameUnits, "AMOUNT_TOO_BIG");

        IERC20Upgradeable(_token).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // collect previous deposits
        uint256[] memory tokenIds = tokensOfOwner(msg.sender);
        (uint256[] memory amounts, address[] memory tokens) = balanceOf(
            tokenIds
        );

        // burn previous state
        for (uint256 i = 0; i < tokenIds.length; i++) {
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
        // in case the vault owner doesn't freeze the vault, if repaymentTimestamp < block.timestamp, allow withdrawing funds
        // so that the funds aren't stucked forever
        require(
            !shouldBeFrozen() ||
                (!frozen && repaymentTimestamp < block.timestamp),
            "SHOULD_BE_FROZEN"
        );

        // collect previous deposits
        uint256[] memory tokenIds = tokensOfOwner(msg.sender);
        require(tokenIds.length > 0, "NFTS_NOT_FOUND");

        (uint256[] memory amounts, address[] memory tokens) = balanceOf(
            tokenIds
        );

        // burn previous state
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.burn(tokenIds[i]);
        }

        // remember in history
        emit Withdrawn(msg.sender, amounts, tokens, tokenIds);

        // withdraw
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20Upgradeable(tokens[i]).safeTransfer(msg.sender, amounts[i]);
        }
    }

    /// @notice redeem all your NFTs for given APR in usdb, can technically be redeemed before repaymentTimestamp passed\
    /// @return _toRepayInRepayToken amount to be repaid in repay token decimals, _feeInRepayToken amount paid in fees in repay token decimals
    function redeem()
        external
        nonReentrant
        returns (uint256 _toRepayInRepayToken, uint256 _feeInRepayToken)
    {
        require(redeemPrepared, "REDEEM_FUNDS_NOT_PREPARED");

        // get user holdings
        uint256[] memory tokenIds = tokensOfOwner(msg.sender);
        require(tokenIds.length > 0, "NFTS_NOT_FOUND");

        // count deposit, yield and fees in repay token
        (uint256[] memory amounts, address[] memory tokens) = balanceOf(
            tokenIds
        );
        uint256 toRepaySameUnits = 0;
        uint256 feeSameUnits = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 amountSameUnits = amounts[i] *
                10**(18 - ERC20Upgradeable(tokens[i]).decimals());
            uint256 roiSameUnits = roi(amountSameUnits);

            toRepaySameUnits += amountSameUnits + roiSameUnits;
            uint256 originalFee = (roiSameUnits * feeLenderOther) / 10000;
            if (tokens[i] == manager.USDB()) {
                originalFee = (roiSameUnits * feeLenderUsdb) / 10000;
            }
            // this should always return something, at least amount [0, originalFee]
            (uint256 amount, uint256 fee) = manager.getDiscountFromFee(
                msg.sender,
                originalFee
            );
            // cannot rug existing vaults by adding more fee than there was before
            // can only add some amount to customers from originalFee
            if (fee > originalFee) {
                fee = originalFee;
            }
            toRepaySameUnits += amount;
            feeSameUnits += fee;
        }

        // burn user tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nft.burn(tokenIds[i]);
        }

        // remember in history
        ERC20Upgradeable token = ERC20Upgradeable(repayToken());
        _toRepayInRepayToken = toRepaySameUnits / 10**(18 - token.decimals());
        _feeInRepayToken = feeSameUnits / 10**(18 - token.decimals());

        emit Redeemed(
            msg.sender,
            tokenIds,
            _toRepayInRepayToken,
            _feeInRepayToken,
            address(token)
        );

        // and sent tokens
        require(_toRepayInRepayToken <= toRepayAmount, "REPAY_OUT_OF_BOUNDS");
        token.safeTransfer(msg.sender, _toRepayInRepayToken);
        token.safeTransfer(manager.DAO(), _feeInRepayToken);
    }

    /// @notice construct new array of tokens as a set
    /// @param _tokens tokens
    /// @param _token token to add to set
    /// @return new array of tokens as a set
    function withToken(address[] memory _tokens, address _token)
        internal
        pure
        returns (address[] memory)
    {
        uint256 index = ArrayUtils.arrayIndex(_tokens, _token, _tokens.length);

        // token not in the list
        if (index == type(uint256).max) {
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
    function withAmount(
        uint256[] memory _amounts,
        address[] memory _tokens,
        uint256 _amount,
        address _token
    ) internal pure returns (uint256[] memory) {
        require(_amounts.length == _tokens.length, "ARRAY_LEN_NOT_MATCH");

        uint256 index = ArrayUtils.arrayIndex(_tokens, _token, _tokens.length);
        // token not in the list
        if (index == type(uint256).max) {
            uint256[] memory newAmounts = new uint256[](_tokens.length + 1);
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
    function unique(uint256[] memory _amounts, address[] memory _tokens)
        internal
        pure
        returns (uint256[] memory _newAmounts, address[] memory _newTokens)
    {
        require(_amounts.length == _tokens.length, "ARRAY_LEN_NOT_MATCH");
        if (_tokens.length == 1) return (_amounts, _tokens);

        uint256 realTokenCount = 0;
        uint256[] memory tmpAmounts = new uint256[](_tokens.length);
        address[] memory tmpTokens = new address[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 index = ArrayUtils.arrayIndex(
                tmpTokens,
                _tokens[i],
                realTokenCount
            );
            // token is not processed yet
            if (index == type(uint256).max) {
                tmpAmounts[realTokenCount] = _amounts[i];
                tmpTokens[realTokenCount] = _tokens[i];
                realTokenCount++;
            }
            // token is already processed
            else {
                tmpAmounts[index] += _amounts[i];
            }
        }

        _newAmounts = new uint256[](realTokenCount);
        _newTokens = new address[](realTokenCount);

        for (uint256 i = 0; i < realTokenCount; i++) {
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
    /// @param _ownerContacts contact info of vault owner
    function changeDescription(
        string calldata _ownerName,
        string calldata _ownerDescription,
        string[] memory _ownerContacts
    ) external onlyOwner {
        require(!shouldBeFrozen(), "SHOULDNT_BE_FROZEN");
        require(!frozen, "ALREADY_FROZEN");

        ownerName = _ownerName;
        ownerDescription = _ownerDescription;
        ownerContacts = _ownerContacts;
    }

    /// @notice change freezeTimestamp to the future
    /// @param _freezeTimestamp changed timestamp
    function setFreezeTimestamp(uint256 _freezeTimestamp) external onlyOwner {
        require(_freezeTimestamp >= freezeTimestamp, "NEW_VALUE_IS_BEFORE_OLD");
        require(
            _freezeTimestamp < repaymentTimestamp,
            "SHOULD_BE_BEFORE_REPAYMENT"
        );
        require(!shouldBeFrozen(), "SHOULDNT_BE_FROZEN");

        freezeTimestamp = _freezeTimestamp;
    }

    /// @notice freeze vault, send fundraised funds into owners wallet, subtracted from vault fee
    function freeze() external nonReentrant onlyOwner {
        require(!frozen, "ALREADY_FROZEN");
        require(shouldBeFrozen(), "SHOULD_BE_FROZEN");

        frozen = true;

        uint256[] memory amounts = new uint256[](allowedTokens.length());
        address[] memory tokens = allowedTokens.values();

        // total amount in 18 decimals
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            ERC20Upgradeable token = ERC20Upgradeable(tokens[i]);
            uint256 balance = token.balanceOf(address(this));
            amounts[i] = balance;
            uint256 balanceSameUnits = balance * 10**(18 - token.decimals());
            // add 100% of investment to return
            totalAmount += balanceSameUnits;

            // add ROI to lender and fee to DAO from lenders return
            uint256 yield = roi(balanceSameUnits);
            if (address(token) == manager.USDB()) {
                totalAmount += yield + (yield * feeLenderUsdb) / 10000;
            } else {
                totalAmount += yield + (yield * feeLenderOther) / 10000;
            }

            if (balance > 0) {
                uint256 toDao = (balance * feeBorrower) / 10000;
                uint256 toVaultOwner = balance - toDao;
                token.safeTransfer(ownerWallet, toVaultOwner);
                token.safeTransfer(manager.DAO(), toDao);
            }
        }

        // set repayment amount in repay token decimals
        ERC20Upgradeable _repayToken = ERC20Upgradeable(repayToken());
        toRepayAmount = totalAmount / 10**(18 - _repayToken.decimals());

        emit Frozen(
            block.timestamp,
            amounts,
            tokens,
            toRepayAmount,
            address(_repayToken)
        );
    }

    /// @notice send all funds for redeem
    /// can be called before redeem timestamp
    function depositForRedeem() external nonReentrant onlyOwner {
        require(frozen, "NOT_FROZEN");
        require(!redeemPrepared, "REDEEM_ALREADY_PREPARED");

        redeemPrepared = true;

        IERC20Upgradeable(repayToken()).safeTransferFrom(
            msg.sender,
            address(this),
            toRepayAmount
        );
    }

    /// @notice can recover tokens sent by mistake to this CA, but cannot recover allowed tokens, those will be sent to vault owner on freeze
    /// @param token CA
    function recoverTokens(IERC20Upgradeable token) external onlyOwner {
        address[] memory allowed = allowedTokens.values();
        for (uint256 i = 0; i < allowed.length; i++) {
            require(
                address(token) != allowed[i],
                "CANNOT_RECOVER_ALLOWED_TOKEN"
            );
        }
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
