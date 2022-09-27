// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./InsuranceVault.sol";

enum PolicyStatus {
    ACTIVE,
    SUSPENDED,
    PAIDOUT,
    CANCELLED
}

struct PolicyHolder {
    uint48 holderId; // ex: 8512232569888
    uint64 inceptionDate; // date of joining insurance
    bool paymentMode; // true -> monthly, false -> annually
    address token; // payment token CA
    uint256 premium;
    uint256 insuredValue;
    string[] holderInfos; // first name, lastName, address
    PolicyStatus status;
}

struct PolicyHolderDto {
    uint48 holderId;
    uint64 inceptionDate;
    bool paymentMode;
    address token;
    uint256 premium;
    uint256 insuredValue;
    string[] holderInfos;
    PolicyStatus status;
    address vaultAddress;
    uint256 index;
}

/// @notice Creates new insurance vaults
contract InsuranceVaultManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable WETH;
    address public immutable USDB;
    address public immutable USDC;

    address public operator;
    address public vaultTemplate;

    /// vetted tokens
    mapping(address => bool) public allowedTokens;

    /// repository for all generated vaults
    mapping(address => address[]) public generatedVaults;
    mapping(uint48 => address) public holderAddress;

    /// @param _WETH weth address
    /// @param _USDB usdb address
    /// @param _USDC usdc address
    constructor(
        address _WETH,
        address _USDB,
        address _USDC
    ) {
        require(_WETH != address(0), "WETH_EMPTY_ADDRESS");
        WETH = _WETH;
        require(_USDB != address(0), "USDB_EMPTY_ADDRESS");
        USDB = _USDB;
        require(_USDC != address(0), "USDC_EMPTY_ADDRESS");
        USDC = _USDC;

        setAllowedToken(_WETH, true);
        setAllowedToken(_USDB, true);
        setAllowedToken(_USDC, true);

        operator = msg.sender;
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
        uint48 indexed _holderId,
        address indexed _holder,
        address indexed _vault,
        address _vaultTemplate
    );

    ///
    /// business logic
    ///

    /// @notice creates new vault
    /// @param _holderId id of privacy holder
    /// @param _holderInfos first name, lastName, and physical address
    /// @param _token payment token CA
    /// @param _premium premium value
    /// @param _paymentMode premium payment mode
    /// @param _insuredValue total insured value
    /// @param _inceptionDate policy inception date
    /// @param _status insurance status
    /// @return _vaultAddress actual address of preconfigured vault
    function createVault(
        uint48 _holderId,
        string[] calldata _holderInfos,
        address _token,
        uint256 _premium,
        bool _paymentMode,
        uint256 _insuredValue,
        uint64 _inceptionDate,
        PolicyStatus _status
    ) external nonReentrant returns (address _vaultAddress) {
        require(
            holderAddress[_holderId] == address(0),
            "HOLDER_ALREADY_REGISTERED"
        );
        require(vaultTemplate != address(0), "MISSING_VAULT_TEMPLATE");
        require(allowedTokens[_token], "TOKEN_NOT_WHITELISTED");
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
            token: _token,
            premium: _premium,
            paymentMode: _paymentMode,
            insuredValue: _insuredValue,
            inceptionDate: _inceptionDate,
            status: _status
        });
        InsuranceVault vault = InsuranceVault(_vaultAddress);
        vault.initialize(param, operator);
        vault.transferOwnership(msg.sender);

        generatedVaults[msg.sender].push(_vaultAddress);
        holderAddress[_holderId] = msg.sender;

        // remember in history
        emit VaultCreated(_holderId, msg.sender, _vaultAddress, vaultTemplate);
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
    /// @param _limit how many items to return in result which are not blacklisted
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
        uint256 index = 0;
        for (uint256 i = _skip; i < limit; i++) {
            InsuranceVault vault = InsuranceVault(generatedVaults[_account][i]);
            // do not send not vetted vaults to the frontend

            page[index++] = PolicyHolderDto({
                vaultAddress: address(vault),
                index: i,
                holderId: vault.holderId(),
                holderInfos: vault.getHolderInfos(),
                token: vault.token(),
                premium: vault.premium(),
                paymentMode: vault.paymentMode(),
                insuredValue: vault.insuredValue(),
                inceptionDate: vault.inceptionDate(),
                status: vault.status()
            });
        }
        return page;
    }

    ///
    /// management
    ///

    /// @notice remove vault holder information
    /// @param _holderId id of privacy holder
    function removeVaultHolder(uint48 _holderId) external onlyOwner {
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
}
