// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../utils/BokkyPooBahsDateTimeLibrary.sol";
import "./InsuranceVaultManager.sol";

/// @notice balance vault
contract InsuranceVault is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    InsuranceVaultManager public manager;
    address public operator;

    /// total deposit amount via payPremium function, to separate normal transfers
    uint256 public depositedAmount;

    /// id of privacy holder
    uint48 public holderId;
    /// first name of privacy holder
    string public firstName;
    /// last name of privacy holder
    string public lastName;
    /// physical addres of privacy holder
    string public physicalAddress;

    /// payment token CA
    address public token;
    /// premium value
    uint256 public premium;
    /// premium payment mode
    bool public paymentMode;
    /// total insured value
    uint256 public insuredValue;
    /// policy inception date
    uint64 public inceptionDate;
    /// policy status
    PolicyStatus public status;
    /// ready to proceed insurance
    bool public readyToProceed;

    struct Beneficiary {
        uint48 payoutFee;
        address wallet;
        string fullName;
    }
    uint256 totalPayoutFee;

    Beneficiary[] public beneficiaries;
    mapping(uint48 => uint48) public beneficiaryIndexes;

    modifier onlyValidStatus() {
        require(
            status == PolicyStatus.ACTIVE || status == PolicyStatus.SUSPENDED,
            "INVALID_STATUS"
        );
        _;
    }

    ///
    /// events
    ///

    /// @notice info about user deposit
    /// @param _user caller
    /// @param _amount deposit amount
    event Deposited(address indexed _user, uint256 _amount);

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

    /// @notice initialize newly created vault
    /// @param _params privacy holder params
    /// @param _operator EOA of operator
    function initialize(PolicyHolder memory _params, address _operator)
        public
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(_params.holderInfos.length == 3, "INFOS_MISSING");

        manager = InsuranceVaultManager(msg.sender);
        operator = _operator;

        holderId = _params.holderId;
        firstName = _params.holderInfos[0];
        lastName = _params.holderInfos[1];
        physicalAddress = _params.holderInfos[2];

        token = _params.token;
        premium = _params.premium;
        paymentMode = _params.paymentMode;
        insuredValue = _params.insuredValue;
        inceptionDate = _params.inceptionDate;
        status = _params.status;
    }

    ///
    /// business logic
    ///

    function getHolderInfos()
        external
        view
        returns (string[] memory holderInfos)
    {
        holderInfos = new string[](3);
        holderInfos[0] = firstName;
        holderInfos[1] = lastName;
        holderInfos[2] = physicalAddress;
    }

    /// @notice add multiple new beneficiaries
    /// @param _beneficiaryIds id array of beneficiary
    /// @param _fullNames full name array of beneficiary
    /// @param _wallets wallet array of beneficiary
    /// @param _payoutFees payout fee array to beneficiary
    function addBeneficiaries(
        uint48[] calldata _beneficiaryIds,
        string[] calldata _fullNames,
        address[] calldata _wallets,
        uint48[] calldata _payoutFees
    ) external nonReentrant onlyOwner {
        require(
            _beneficiaryIds.length == _fullNames.length &&
                _beneficiaryIds.length == _wallets.length &&
                _beneficiaryIds.length == _fullNames.length,
            "INVALID_ARGUMENTS_LENGTH"
        );
        for (uint256 i; i < _beneficiaryIds.length; i += 1) {
            uint256 index = beneficiaryIndexes[_beneficiaryIds[i]];
            if (index > 0) {
                totalPayoutFee =
                    totalPayoutFee +
                    _payoutFees[i] -
                    beneficiaries[index - 1].payoutFee;
                beneficiaries[index - 1] = Beneficiary({
                    payoutFee: _payoutFees[i],
                    wallet: _wallets[i],
                    fullName: _fullNames[i]
                });
            } else {
                totalPayoutFee += _payoutFees[i];
                beneficiaries.push(
                    Beneficiary({
                        payoutFee: _payoutFees[i],
                        wallet: _wallets[i],
                        fullName: _fullNames[i]
                    })
                );
            }
        }
    }

    /// @notice pay premium based on initialized mode
    /// @param _amount token amount
    /// @return _status latest insurance status
    function payPremium(uint256 _amount)
        external
        nonReentrant
        onlyValidStatus
        returns (PolicyStatus _status)
    {
        require(totalPayoutFee > 0, "NO_BENEFICIARIES_ADDED");

        (uint256 _outstanding, ) = this.checkPolicyStatus();
        uint256 _amountToTransfer = Math.min(_amount, _outstanding);
        IERC20Upgradeable(token).safeTransferFrom(
            msg.sender,
            address(this),
            _amountToTransfer
        );
        depositedAmount += _amountToTransfer;
        status = _status = _outstanding > _amount
            ? PolicyStatus.SUSPENDED
            : PolicyStatus.ACTIVE;

        emit Deposited(msg.sender, _amountToTransfer);
    }

    /// @notice after death guarantee pay beneficiaries
    /// @return _status latest insurance status
    function proceedInsurance()
        external
        nonReentrant
        onlyValidStatus
        returns (PolicyStatus _status)
    {
        (uint256 _outstanding, ) = this.checkPolicyStatus();
        status = _status = _outstanding > 0
            ? PolicyStatus.CANCELLED
            : PolicyStatus.PAIDOUT;

        if (_outstanding > 0)
            IERC20Upgradeable(token).safeTransferFrom(
                address(this),
                address(manager),
                depositedAmount
            );
        else {
            for (uint256 i; i < beneficiaries.length; i += 1) {
                IERC20Upgradeable(token).safeTransferFrom(
                    address(this),
                    beneficiaries[i].wallet,
                    (depositedAmount * beneficiaries[i].payoutFee) /
                        totalPayoutFee
                );
            }
        }
        depositedAmount = 0;
    }

    /// @notice check policy status and oustanding amount altogether
    function checkPolicyStatus() external view returns (uint256, PolicyStatus) {
        if (status == PolicyStatus.PAIDOUT || status == PolicyStatus.CANCELLED)
            return (0, status);

        uint256 timesToPay = BokkyPooBahsDateTimeLibrary.getYear(
            block.timestamp
        ) - BokkyPooBahsDateTimeLibrary.getYear(uint256(inceptionDate));
        if (paymentMode) {
            timesToPay =
                (timesToPay * 12) +
                BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp) -
                BokkyPooBahsDateTimeLibrary.getMonth(uint256(inceptionDate));
        }
        uint256 shouldPay = timesToPay * premium;
        uint256 alreadyPaid = insuredValue + depositedAmount;

        return (
            shouldPay - Math.min(shouldPay, alreadyPaid),
            shouldPay > alreadyPaid
                ? PolicyStatus.SUSPENDED
                : PolicyStatus.ACTIVE
        );
    }

    function getReadyToProceed() external onlyValidStatus {
        require(msg.sender == operator, "NOT_OPERATOR");
        readyToProceed = true;
    }

    function recoverTokens(IERC20Upgradeable _token) external onlyOwner {
        _token.safeTransfer(owner(), _token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
