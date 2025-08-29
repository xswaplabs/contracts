// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Payments} from "../modules/Payments.sol";
import {V2SwapRouter} from "../modules/v2/V2SwapRouter.sol";
import {V3SwapRouter} from "../modules/v3/V3SwapRouter.sol";
import {ReferrerProxy} from "../modules/referrer/ReferrerProxy.sol";
import {ActionConstants} from "../libraries/ActionConstants.sol";
import {BytesLib} from "../modules/v3/BytesLib.sol";
import {CalldataDecoder} from "../libraries/CalldataDecoder.sol";
import {Commands} from "../libraries/Commands.sol";
import {Lock} from "./Lock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Dispatcher is
    Payments,
    V2SwapRouter,
    V3SwapRouter,
    ReferrerProxy,
    Lock
{
    using BytesLib for bytes;
    using CalldataDecoder for bytes;

    error InvalidCommandType(uint256 commandType);
    error BalanceTooLow();

    /**
     * @notice Execute a batch of commands
     * @param commands The commands to execute
     * @param inputs The inputs for the commands
     */
    function execute(
        bytes calldata commands,
        bytes[] calldata inputs
    ) external payable virtual;

    /**
     * @notice Get the message sender
     * @return The message sender
     */
    function msgSender() public view virtual returns (address) {
        return _getLocker();
    }

    /**
     * @notice Dispatch a command
     * @param commandType The command type
     * @param inputs The inputs for the command
     * @return success Whether the command was executed successfully
     * @return output The output of the command
     */
    function dispatch(
        bytes1 commandType,
        bytes calldata inputs
    ) internal returns (bool success, bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        success = true;

        // First branch: 0x00 <= command < 0x08
        if (command < 0x08) {
            if (command == Commands.V3_SWAP) {
                // equivalent: abi.decode(inputs, (address, address, uint256, uint256, bytes, address[], bool))
                address factory;
                address recipient;
                uint256 amountIn;
                uint256 amountOutMin;
                bool payerIsUser;
                assembly {
                    factory := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    amountIn := calldataload(add(inputs.offset, 0x40))
                    amountOutMin := calldataload(add(inputs.offset, 0x60))
                    // 0x80 offset is the path
                    // 0xa0 offset is pools
                    payerIsUser := calldataload(add(inputs.offset, 0xc0))
                }
                bytes calldata path = inputs.toBytes(4);
                address[] calldata pools = inputs.toAddressArray(5);
                address payer = payerIsUser ? msgSender() : address(this);
                _v3Swap(
                    factory,
                    map(recipient),
                    amountIn,
                    amountOutMin,
                    path,
                    pools,
                    payer
                );
            } else if (command == Commands.SWEEP) {
                // equivalent:  abi.decode(inputs, (address, address, uint256))
                address token;
                address recipient;
                uint256 amountMin;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    amountMin := calldataload(add(inputs.offset, 0x40))
                }
                Payments.sweep(token, map(recipient), amountMin);
            } else if (command == Commands.TRANSFER_FROM) {
                // equivalent: abi.decode(inputs, (address, address, uint160))
                address token;
                address recipient;
                uint160 amount;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    amount := calldataload(add(inputs.offset, 0x40))
                }
                transferFrom(token, msgSender(), map(recipient), amount);
            } else if (command == Commands.TRANSFER) {
                // equivalent:  abi.decode(inputs, (address, address, uint256))
                address token;
                address recipient;
                uint256 value;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    value := calldataload(add(inputs.offset, 0x40))
                }
                Payments.pay(token, map(recipient), value);
            } else {
                revert InvalidCommandType(command);
            }
        }
        // Second branch: 0x08 <= command < 0x10
        else if (command < 0x10) {
            if (command == Commands.V2_SWAP) {
                // equivalent: abi.decode(inputs, (address, address, uint256, uint256, address[], uint16[], bool))
                address factory;
                address recipient;
                uint256 amountIn;
                uint256 amountOutMin;
                bool payerIsUser;
                assembly {
                    factory := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    amountIn := calldataload(add(inputs.offset, 0x40))
                    amountOutMin := calldataload(add(inputs.offset, 0x60))
                    // 0x80 offset is the path
                    // 0xa0 offset is swapFees
                    payerIsUser := calldataload(add(inputs.offset, 0xc0))
                }
                address[] calldata path = inputs.toAddressArray(4);
                uint16[] calldata swapFees = inputs.toUint16Array(5);
                address payer = payerIsUser ? msgSender() : address(this);
                _v2Swap(
                    factory,
                    swapFees,
                    map(recipient),
                    amountIn,
                    amountOutMin,
                    path,
                    payer
                );
            } else if (command == Commands.WRAP_ETH) {
                // equivalent: abi.decode(inputs, (address, uint256))
                address recipient;
                uint256 amount;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amount := calldataload(add(inputs.offset, 0x20))
                }
                Payments.wrapETH(map(recipient), amount);
            } else if (command == Commands.UNWRAP_WETH) {
                // equivalent: abi.decode(inputs, (address, uint256))
                address recipient;
                uint256 amountMin;
                assembly {
                    recipient := calldataload(inputs.offset)
                    amountMin := calldataload(add(inputs.offset, 0x20))
                }
                Payments.unwrapWETH9(map(recipient), amountMin);
            } else if (command == Commands.PAY_PORTION) {
                // equivalent:  abi.decode(inputs, (address, address, uint256))
                address token;
                address recipient;
                uint256 bips;
                assembly {
                    token := calldataload(inputs.offset)
                    recipient := calldataload(add(inputs.offset, 0x20))
                    bips := calldataload(add(inputs.offset, 0x40))
                }
                Payments.payPortion(token, map(recipient), bips);
            } else {
                revert InvalidCommandType(command);
            }
        }
        // Third branch: 0x10 <= command < 0x20
        else if (command < 0x20) {
            if (command == Commands.BALANCE_CHECK_ERC20) {
                // equivalent: abi.decode(inputs, (address, address, uint256))
                address owner;
                address token;
                uint256 minBalance;
                assembly {
                    owner := calldataload(inputs.offset)
                    token := calldataload(add(inputs.offset, 0x20))
                    minBalance := calldataload(add(inputs.offset, 0x40))
                }
                success = (IERC20(token).balanceOf(owner) >= minBalance);
                if (!success) output = abi.encodePacked(BalanceTooLow.selector);
            } else if (command == Commands.SET_REFERRER) {
                // equivalent: abi.decode(inputs, (address))
                address referrer;
                assembly {
                    referrer := calldataload(inputs.offset)
                }
                setReferrer(referrer, msgSender());
            } else {
                revert InvalidCommandType(command);
            }
        }
        // Fourth branch: 0x20 <= command <= 0x3f (Advanced commands)
        else {
            if (command == Commands.EXECUTE_SUB_PLAN) {
                (bytes calldata _commands, bytes[] calldata _inputs) = inputs
                    .decodeCommandsAndInputs();
                (success, output) = (address(this)).call(
                    abi.encodeCall(Dispatcher.execute, (_commands, _inputs))
                );
            } else {
                revert InvalidCommandType(command);
            }
        }
    }

    /// @notice Calculates the recipient address for a command
    /// @param recipient The recipient or recipient-flag for the command
    /// @return output The resultant recipient for the command
    function map(address recipient) internal view returns (address) {
        if (recipient == ActionConstants.MSG_SENDER) {
            return msgSender();
        } else if (recipient == ActionConstants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }
}
