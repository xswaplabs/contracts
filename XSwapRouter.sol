// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IXSwapRouter} from "./interfaces/IXSwapRouter.sol";
import {PaymentsImmutables} from "./modules/PaymentsImmutables.sol";
import {V3SwapRouter} from "./modules/v3/V3SwapRouter.sol";
import {ReferrerProxy} from "./modules/referrer/ReferrerProxy.sol";
import {Dispatcher} from "./base/Dispatcher.sol";
import {Commands} from "./libraries/Commands.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

/**
 * @title XSwapRouterV1
 * @notice The Safest DEX Aggregator
 * @dev XSwapRouter contract for XSwap protocol
 * @author https://xswap.app
 */
contract XSwapRouter is IXSwapRouter, Dispatcher {
    constructor(
        IWETH9 weth9,
        address referrer,
        address[] memory v3Factories
    )
        PaymentsImmutables(weth9)
        V3SwapRouter(v3Factories)
        ReferrerProxy(referrer)
    {}

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
        _;
    }

    receive() external payable {
        if (msg.sender != address(WETH9)) revert InvalidEthSender();
    }

    function execute(
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable checkDeadline(deadline) {
        execute(commands, inputs);
    }

    /// @inheritdoc Dispatcher
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs
    ) public payable override isNotLocked {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        // loop through all given commands, execute them and pass along outputs as defined
        for (
            uint256 commandIndex = 0;
            commandIndex < numCommands;
            commandIndex++
        ) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            (success, output) = dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed({
                    commandIndex: commandIndex,
                    message: output
                });
            }
        }
    }

    function successRequired(bytes1 command) internal pure returns (bool) {
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }
}
