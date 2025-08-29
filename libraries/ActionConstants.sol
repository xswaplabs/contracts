// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Action constants
/// @notice Constants used in actions
/// @dev Constants are a more gas-efficient alternative to literal values
library ActionConstants {
    /// @notice Used to indicate that an operation should use the entire balance of a contract-held currency
    /// This value is equivalent to 1<<255, i.e. a number with the highest significant bit set to 1
    uint256 internal constant CONTRACT_BALANCE =
        0x8000000000000000000000000000000000000000000000000000000000000000;

    /// @notice Used to indicate that the recipient of an operation should be msgSender
    address internal constant MSG_SENDER = address(1);

    /// @notice Used to indicate that the recipient of an operation should be address(this)
    address internal constant ADDRESS_THIS = address(2);
}
