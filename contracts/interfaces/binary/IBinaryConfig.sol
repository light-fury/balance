// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IBinaryConfig {
    function treasury() external view returns (address);

    function tradingFee() external view returns (uint256);

    function claimNoticePeriod() external view returns (uint256);
}
