// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./BalanceVaultManager.sol";

/// @notice balance vault
contract BalanceVault is OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// name of the vault owner
    string public ownerName;
    /// description of the vault owner
    string public ownerDescription;
    /// contact info of the vault owner
    string public ownerContactInfo;

    /// unmodifiable balance vault manager
    BalanceVaultManager public manager;
    /// unmodifiable wallet of the vault owner where all funds are going
    address public ownerWallet;
    /// unmodifiable funding amount with 18 decimals
    uint public fundingAmount;
    /// unmodifiable timestamp to freeze this fundrising
    uint public freezeTimestamp;
    /// unmodifiable timestamp to the payout of given APR
    uint public payoutTimestamp;
    /// unmodifiable apr in 2 decimals
    uint public apr;

    address public USDB;
    uint public feeUsdb;
    uint public feeOther;

    /// unmodifiable allowed tokens which are 1:1 used for funding
    mapping(address => bool) public allowedTokens;

    ///
    /// events
    ///

    event Deposited(address indexed _user, uint _amount, address _token);

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
        fundingAmount = _params.fundingAmount;

        for (uint i = 0; i < _params.allowedTokens.length; i++) {
            allowedTokens[_params.allowedTokens[i]] = true;
        }

        freezeTimestamp = _params.freezeTimestamp;
        payoutTimestamp = _params.payoutTimestamp;
        apr = _params.apr;
        USDB = manager.USDB();
        feeUsdb = _params.feeUsdb;
        feeOther = _params.feeOther;
    }

    ///
    /// business logic
    ///

    function deposit(uint _amount, address _token) external nonReentrant {
        require(allowedTokens[_token], "TOKEN_NOT_WHITELISTED");
        IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposited(msg.sender, _amount, _token);
    }

    function withdraw() external nonReentrant {

    }

    function redeem() external nonReentrant {

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
        ownerName = _ownerName;
        ownerDescription = _ownerDescription;
        ownerContactInfo = _ownerContactInfo;
    }

    function recoverTokens(IERC20Upgradeable token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}