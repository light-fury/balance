// solhint-disable
// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./InsuranceVault.sol";

// Active: while alive
// Suspended: after death, if lapse
// PaidOut: after death, paid out
enum PolicyStatus {
    ACTIVE,
    SUSPENDED,
    PAIDOUT
}

struct PolicyHolder {
    string holderId;
    string[] holderInfos; // first name, lastName, address
    uint256 premium; // amount to pay per cycle
    bool paymentMode; // true -> monthly, false -> annually
    uint256 insuredValue; // total insured value
    uint64 inceptionDate; // date of joining insurance
}

struct PolicyHolderDto {
    string holderId;
    string[] holderInfos;
    uint256 deposit;
    uint256 premium;
    bool paymentMode;
    uint256 insuredValue;
    uint64 inceptionDate;
    PolicyStatus status;
    bool isDeathVerified;
    address vaultAddress;
    uint256 index;
}

/// @notice Creates new insurance vaults
contract InsuranceVaultManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable USDB;

    address public operator;
    address public vaultTemplate;

    /// allowed tokens
    mapping(address => bool) public allowedTokens;

    /// repository for all generated vaults
    mapping(address => address[]) public generatedVaults;
    mapping(string => address) public holderAddress;

    /// @param _USDB usdb address
    constructor(address _USDB) {
        require(_USDB != address(0), "USDB_EMPTY_ADDRESS");
        USDB = _USDB;
        operator = msg.sender;

        setAllowedToken(_USDB, true);
    }

    ///
    /// events
    ///

    /// @notice informs about creating new vault
    /// @param _holderId privacy holder id
    /// @param _holder privacy holder address
    /// @param _vault CA of the vault
    /// @param _vaultTemplate vault template CA from which it was created
    event VaultCreated(
        string indexed _holderId,
        address indexed _holder,
        address indexed _vault,
        address _vaultTemplate
    );

    /// @notice informs about paying premium
    /// @param _holder privacy holder address
    /// @param _amount amount totally paid
    event PremiumPaid(address indexed _holder, uint256 _amount);

    ///
    /// business logic
    ///

    /// @notice creates new vault
    /// @param _holderId id of privacy holder
    /// @param _holderInfos first name, lastName, and physical address
    /// @param _premium premium value
    /// @param _paymentMode premium payment mode
    /// @param _insuredValue total insured value
    /// @param _inceptionDate policy inception date
    /// @return _vaultAddress actual address of preconfigured vault
    function createVault(
        string calldata _holderId,
        string[] calldata _holderInfos,
        uint256 _premium,
        bool _paymentMode,
        uint256 _insuredValue,
        uint64 _inceptionDate
    ) external nonReentrant returns (address _vaultAddress) {
        require(
            holderAddress[_holderId] == address(0),
            "HOLDER_ALREADY_REGISTERED"
        );
        require(vaultTemplate != address(0), "MISSING_VAULT_TEMPLATE");
        require(
            _inceptionDate <= block.timestamp,
            "INCEPTION_DATE_SHOULD_BE_IN_PAST"
        );
        require(_holderInfos.length == 3, "INFOS_MISSING");

        // EIP1167 clone factory
        _vaultAddress = Clones.clone(vaultTemplate);

        PolicyHolder memory param = PolicyHolder({
            holderId: _holderId,
            holderInfos: _holderInfos,
            premium: _premium,
            paymentMode: _paymentMode,
            insuredValue: _insuredValue,
            inceptionDate: _inceptionDate
        });
        InsuranceVault vault = InsuranceVault(_vaultAddress);
        vault.initialize(param, operator);
        vault.transferOwnership(msg.sender);

        generatedVaults[msg.sender].push(_vaultAddress);
        holderAddress[_holderId] = _vaultAddress;

        // remember in history
        emit VaultCreated(_holderId, msg.sender, _vaultAddress, vaultTemplate);
    }

    /// @notice pay all created vaults premiums to here
    function payPremium() external nonReentrant {
        address[] memory vaults = generatedVaults[msg.sender];
        require(vaults.length > 0, "NO_CLIENTS");

        uint256 amountToPay;
        for (uint256 i; i < vaults.length; i += 1) {
            if (InsuranceVault(vaults[i]).status() == PolicyStatus.ACTIVE) {
                amountToPay += InsuranceVault(vaults[i]).premium();
                InsuranceVault(vaults[i]).payPremium();
            }
        }
        if (amountToPay > 0) {
            IERC20(USDB).safeTransferFrom(
                msg.sender,
                address(this),
                amountToPay
            );
            emit PremiumPaid(msg.sender, amountToPay);
        }
    }

    /// @notice proceed insurance to beneficiaries
    function proceedInsurance() external {
        InsuranceVault vault = InsuranceVault(msg.sender);
        uint256 insuredVaule = vault.insuredValue();
        uint256 totalPayoutFee = vault.totalPayoutFee();
        BeneficiaryDto[] memory beneficiaries = vault.getBeneficiariesPage(
            0,
            vault.getBeneficiariesLength()
        );
        for (uint256 i; i < beneficiaries.length; i += 1) {
            IERC20(USDB).safeTransfer(
                beneficiaries[i].wallet,
                (insuredVaule * beneficiaries[i].payoutFee) / totalPayoutFee
            );
        }
    }

    ///
    /// paging
    ///

    /// @notice get generated vaults length for paging
    /// @param _account address of account to watch
    /// @return generated vaults length for paging
    function getGeneratedVaultsLength(address _account)
        external
        view
        returns (uint256)
    {
        return generatedVaults[_account].length;
    }

    /// @notice skip/limit paging on-chain impl
    /// @param _account address of account to watch
    /// @param _skip how many items from beginning to skip
    /// @param _limit how many items to return in result
    /// @return page of PolicyHolderDto
    function getGeneratedVaultsPage(
        address _account,
        uint256 _skip,
        uint256 _limit
    ) external view returns (PolicyHolderDto[] memory) {
        if (_skip >= generatedVaults[_account].length)
            return new PolicyHolderDto[](0);

        uint256 limit = Math.min(
            _skip + _limit,
            generatedVaults[_account].length
        );
        PolicyHolderDto[] memory page = new PolicyHolderDto[](limit);
        uint256 index;
        for (uint256 i = _skip; i < limit; i++) {
            InsuranceVault vault = InsuranceVault(generatedVaults[_account][i]);
            // do not send not vetted vaults to the frontend
            if (holderAddress[vault.holderId()] == address(0)) continue;

            page[index++] = PolicyHolderDto({
                holderId: vault.holderId(),
                holderInfos: vault.getHolderInfos(),
                deposit: vault.depositedAmount(),
                premium: vault.premium(),
                paymentMode: vault.paymentMode(),
                insuredValue: vault.insuredValue(),
                inceptionDate: vault.inceptionDate(),
                status: vault.status(),
                isDeathVerified: vault.isDeathVerified(),
                vaultAddress: address(vault),
                index: i
            });
        }
        return page;
    }

    function getPoolBalance() external view returns (uint256) {
        return IERC20(USDB).balanceOf(address(this));
    }

    ///
    /// management
    ///

    function reset() external {
        address[] memory vaults = generatedVaults[msg.sender];
        if (vaults.length == 0) return;

        for (uint256 i = vaults.length - 1; i >= 0; i -= 1) {
            InsuranceVault vault = InsuranceVault(vaults[i]);
            delete holderAddress[vault.holderId()];
            generatedVaults[msg.sender].pop();
        }
    }

    /// @notice remove vault holder information
    /// @param _holderId id of privacy holder
    function removeVaultHolder(string calldata _holderId) external onlyOwner {
        require(holderAddress[_holderId] != address(0), "NOT_EXISTS");
        delete holderAddress[_holderId];
    }

    /// @notice change operator address
    /// @param _operator operator EOA
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "EMPTY_ADDRESS");
        operator = _operator;
    }

    /// @notice change vault template, e.g. can deploy new version with same signature
    /// @param _vaultTemplate CA for new vault
    function setVaultTemplate(address _vaultTemplate) external onlyOwner {
        require(_vaultTemplate != address(0), "EMPTY_ADDRESS");
        vaultTemplate = _vaultTemplate;
    }

    /// @notice add/remove allowed token
    /// @param _token token CA
    /// @param _allow true to allow, false to disallow
    function setAllowedToken(address _token, bool _allow) public onlyOwner {
        allowedTokens[_token] = _allow;
    }

    function recoverTokens(IERC20 _token) external onlyOwner {
        _token.safeTransfer(owner(), _token.balanceOf(address(this)));
    }

    function recoverEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
