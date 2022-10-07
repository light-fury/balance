// solhint-disable
// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../../utils/BokkyPooBahsDateTimeLibrary.sol";
import "./InsuranceVaultManager.sol";

struct BeneficiaryDto {
    string beneficiaryId;
    string fullName;
    address wallet;
    uint48 payoutFee;
    uint256 index;
}

struct Beneficiary {
    string beneficiaryId;
    string fullName;
    address wallet;
    uint48 payoutFee;
}

/// @notice balance vault
contract InsuranceVault is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public manager;
    address public operator;

    /// total deposit amount via payPremium function, to separate normal transfers
    uint256 public depositedAmount;

    /// id of privacy holder
    string public holderId;
    /// first name of privacy holder
    string public firstName;
    /// last name of privacy holder
    string public lastName;
    /// physical addres of privacy holder
    string public physicalAddress;

    /// premium value
    uint256 public premium;
    /// premium payment mode
    bool public paymentMode;
    /// total insured value
    uint256 public insuredValue;
    /// policy inception date
    uint64 public inceptionDate;
    /// vault creation date
    uint64 public createDate;
    /// policy status
    PolicyStatus public status;
    /// ready to proceed insurance if death simulated in poc
    bool public isDeathVerified;
    /// just for poc of showing death certifacte for one vault
    bool public isRealDeath;
    /// sum of all beneficiaries payout fee
    uint256 public totalPayoutFee;

    Beneficiary[] public beneficiaries;
    mapping(string => uint256) public beneficiaryIndexes;

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

        manager = msg.sender;
        operator = _operator;

        holderId = _params.holderId;
        firstName = _params.holderInfos[0];
        lastName = _params.holderInfos[1];
        physicalAddress = _params.holderInfos[2];

        premium = _params.premium;
        paymentMode = _params.paymentMode;
        insuredValue = _params.insuredValue;
        inceptionDate = _params.inceptionDate;
        createDate = uint64(block.timestamp);
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
        string[] calldata _beneficiaryIds,
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
                    beneficiaryId: _beneficiaryIds[i],
                    fullName: _fullNames[i],
                    wallet: _wallets[i],
                    payoutFee: _payoutFees[i]
                });
            } else {
                totalPayoutFee += _payoutFees[i];
                beneficiaries.push(
                    Beneficiary({
                        beneficiaryId: _beneficiaryIds[i],
                        fullName: _fullNames[i],
                        wallet: _wallets[i],
                        payoutFee: _payoutFees[i]
                    })
                );
            }
        }
    }

    /// @notice pay premium by manager at once
    function payPremium() external {
        require(msg.sender == manager, "NOT_MANAGER");
        depositedAmount += premium;
    }

    function prepare() external {
        require(msg.sender == manager, "NOT_MANAGER");
        isRealDeath = true;
    }

    function verifyDeath() external {
        require(msg.sender == operator, "NOT_OPERATOR");
        isDeathVerified = true;
    }

    /// @notice after death guarantee pay beneficiaries
    function proceedInsurance() external nonReentrant {
        require(isDeathVerified, "DEATH_NOT_VERIFIED");
        require(status == PolicyStatus.ACTIVE, "ALREADY_PROCEEDED");
        InsuranceVaultManager(manager).proceedInsurance();
        status = PolicyStatus.PAIDOUT;
    }

    /* 
    /// @notice check policy status and oustanding amount altogether
    function checkPolicyStatus() external view returns (uint256, PolicyStatus) {
        if (status == PolicyStatus.PAIDOUT || status == PolicyStatus.CANCELLED)
            return (0, status);

        uint256 timesToPay = BokkyPooBahsDateTimeLibrary.getYear(
            block.timestamp
        ) - BokkyPooBahsDateTimeLibrary.getYear(uint256(createDate));
        if (paymentMode) {
            timesToPay =
                (timesToPay * 12) +
                BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp) -
                BokkyPooBahsDateTimeLibrary.getMonth(uint256(createDate));
        }
        uint256 shouldPay = timesToPay * premium;

        return (
            shouldPay - Math.min(shouldPay, depositedAmount),
            shouldPay > depositedAmount
                ? PolicyStatus.SUSPENDED
                : PolicyStatus.ACTIVE
        );
    }
 */
    ///
    /// paging
    ///

    /// @notice get generated vaults length for paging
    /// @return beneficiaries vaults length for paging
    function getBeneficiariesLength() external view returns (uint256) {
        return beneficiaries.length;
    }

    /// @notice skip/limit paging on-chain impl
    /// @param _skip how many items from beginning to skip
    /// @param _limit how many items to return in result
    /// @return page of BeneficiaryDto
    function getBeneficiariesPage(uint256 _skip, uint256 _limit)
        external
        view
        returns (BeneficiaryDto[] memory)
    {
        if (_skip >= beneficiaries.length) return new BeneficiaryDto[](0);

        uint256 limit = Math.min(_skip + _limit, beneficiaries.length);
        BeneficiaryDto[] memory page = new BeneficiaryDto[](limit);
        uint256 index = 0;
        for (uint256 i = _skip; i < limit; i++) {
            Beneficiary memory beneficiary = beneficiaries[i];
            page[index++] = BeneficiaryDto({
                index: i,
                beneficiaryId: beneficiary.beneficiaryId,
                fullName: beneficiary.fullName,
                wallet: beneficiary.wallet,
                payoutFee: beneficiary.payoutFee
            });
        }
        return page;
    }

    function recoverTokens(IERC20Upgradeable _token) external onlyOwner {
        _token.safeTransfer(owner(), _token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
