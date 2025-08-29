// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {Constants} from "../libraries/Constants.sol";
import {PaymentsImmutables} from "./PaymentsImmutables.sol";
import {SafeTransferLib} from "../libraries/SafeTransferLib.sol";
import {BipsLibrary} from "../libraries/BipsLibrary.sol";
import {ActionConstants} from "../libraries/ActionConstants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Payments contract
/// @notice Performs various operations around the payment of ETH and tokens
abstract contract Payments is PaymentsImmutables {
    using SafeTransferLib for address;
    using BipsLibrary for uint256;

    error InsufficientToken();
    error InsufficientETH();

    /// @notice Performs a transferFrom on a token
    /// @param token The token to transfer
    /// @param from The address to transfer from
    /// @param to The recipient of the transfer
    /// @param amount The amount to transfer
    function transferFrom(
        address token,
        address from,
        address to,
        uint160 amount
    ) internal {
        token.safeTransferFrom(from, to, amount);
    }

    /// @notice Pays an amount of ETH or ERC20 to a recipient
    /// @param token The token to pay (can be ETH using Constants.ETH)
    /// @param payer The address that will pay the amount
    /// @param recipient The address that will receive the payment
    /// @param amount The amount to pay
    function payOrTransferFrom(
        address token,
        address payer,
        address recipient,
        uint256 amount
    ) internal {
        if (payer == address(this)) {
            pay(token, recipient, amount);
        } else {
            token.safeTransferFrom(payer, recipient, amount);
        }
    }

    /// @notice Pays an amount of ETH or ERC20 to a recipient
    /// @param token The token to pay (can be ETH using Constants.ETH)
    /// @param recipient The address that will receive the payment
    /// @param value The amount to pay
    function pay(address token, address recipient, uint256 value) internal {
        if (token == Constants.ETH) {
            recipient.safeTransferETH(value);
        } else {
            if (value == ActionConstants.CONTRACT_BALANCE) {
                value = IERC20(token).balanceOf(address(this));
            }
            token.safeTransfer(recipient, value);
        }
    }

    /// @notice Pays a proportion of the contract's ETH or ERC20 to a recipient
    /// @param token The token to pay (can be ETH using Constants.ETH)
    /// @param recipient The address that will receive payment
    /// @param bips Portion in bips of whole balance of the contract
    function payPortion(
        address token,
        address recipient,
        uint256 bips
    ) internal {
        if (token == Constants.ETH) {
            uint256 balance = address(this).balance;
            uint256 amount = balance.calculatePortion(bips);
            recipient.safeTransferETH(amount);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 amount = balance.calculatePortion(bips);
            token.safeTransfer(recipient, amount);
        }
    }

    /// @notice Sweeps all of the contract's ERC20 or ETH to an address
    /// @param token The token to sweep (can be ETH using Constants.ETH)
    /// @param recipient The address that will receive payment
    /// @param amountMinimum The minimum desired amount
    function sweep(
        address token,
        address recipient,
        uint256 amountMinimum
    ) internal {
        uint256 balance;
        if (token == Constants.ETH) {
            balance = address(this).balance;
            if (balance < amountMinimum) revert InsufficientETH();
            if (balance > 0) recipient.safeTransferETH(balance);
        } else {
            balance = IERC20(token).balanceOf(address(this));
            if (balance < amountMinimum) revert InsufficientToken();
            if (balance > 0) token.safeTransfer(recipient, balance);
        }
    }

    /// @notice Wraps an amount of ETH into WETH
    /// @param recipient The recipient of the WETH
    /// @param amount The amount to wrap (can be CONTRACT_BALANCE)
    function wrapETH(address recipient, uint256 amount) internal {
        if (amount == ActionConstants.CONTRACT_BALANCE) {
            amount = address(this).balance;
        } else if (amount > address(this).balance) {
            revert InsufficientETH();
        }
        if (amount > 0) {
            WETH9.deposit{value: amount}();
            if (recipient != address(this)) {
                WETH9.transfer(recipient, amount);
            }
        }
    }

    /// @notice Unwraps all of the contract's WETH into ETH
    /// @param recipient The recipient of the ETH
    /// @param amountMinimum The minimum amount of ETH desired
    function unwrapWETH9(address recipient, uint256 amountMinimum) internal {
        uint256 value = WETH9.balanceOf(address(this));
        if (value < amountMinimum) {
            revert InsufficientETH();
        }
        if (value > 0) {
            WETH9.withdraw(value);
            if (recipient != address(this)) {
                recipient.safeTransferETH(value);
            }
        }
    }
}
