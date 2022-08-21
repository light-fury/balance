// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

library ArrayUtils {

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
}