// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

/// @title Commands
/// @notice Command Flags used to decode commands
library Commands {
    // Masks to extract certain bits of commands
    bytes1 internal constant FLAG_ALLOW_REVERT = 0x80;
    bytes1 internal constant COMMAND_TYPE_MASK = 0x3f;

    // Command Types. Maximum supported command at this moment is 0x3f.
    // The commands are executed in nested if blocks to minimise gas consumption
    // Commands are ordered by usage frequency and gas consumption optimization

    // First branch: 0x00 <= command < 0x08
    uint256 constant V3_SWAP = 0x00; // V3 swap
    uint256 constant SWEEP = 0x01; // Sweep
    uint256 constant TRANSFER_FROM = 0x02; // Transfer from user balance to contract
    uint256 constant TRANSFER = 0x03; // Transfer
    // COMMAND_PLACEHOLDER = 0x04 -> 0x07;

    // Second branch: 0x08 <= command < 0x10
    uint256 constant V2_SWAP = 0x08; // V2 swap
    uint256 constant WRAP_ETH = 0x09; // Wrap ETH
    uint256 constant UNWRAP_WETH = 0x0a; // Unwrap WETH
    uint256 constant PAY_PORTION = 0x0b; // Pay portion
    // COMMAND_PLACEHOLDER = 0x0c -> 0x0f;

    // Third branch: 0x10 <= command < 0x20
    uint256 constant BALANCE_CHECK_ERC20 = 0x10; // Balance check ERC20
    uint256 constant SET_REFERRER = 0x11; // Set referrer
    // COMMAND_PLACEHOLDER = 0x12 -> 0x20

    // Fourth branch: 0x20 <= command <= 0x3f (Advanced commands)
    uint256 constant EXECUTE_SUB_PLAN = 0x21; // Execute sub plan
    // COMMAND_PLACEHOLDER for 0x22 to 0x3f
}
