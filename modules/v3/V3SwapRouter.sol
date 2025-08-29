// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IUniV3Quoter, IUniV3Factory, IUniV3Pool} from "../../interfaces/IUniV3.sol";
import {IUniV3Callback} from "../../interfaces/IUniV3Callback.sol";
import {SafeTransferLib} from "../../libraries/SafeTransferLib.sol";
import {InvalidAmount, InvalidPool, SlippageIsTooLow} from "../../libraries/Errors.sol";
import {Payments} from "../Payments.sol";
import {V3Path} from "./V3Path.sol";
import {BytesLib} from "./BytesLib.sol";
import {CalldataDecoder} from "../../libraries/CalldataDecoder.sol";
import {ActionConstants} from "../../libraries/ActionConstants.sol";
import {TickMath} from "./TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract V3SwapRouter is IUniV3Callback, Payments {
    using V3Path for bytes;
    using BytesLib for bytes;
    using SafeCast for uint256;
    using SafeTransferLib for address;
    using CalldataDecoder for bytes;

    /// @dev Mapping of factory addresses to their validity status
    mapping(address => bool) private _factoryOf;

    constructor(address[] memory factories) {
        for (uint i = 0; i < factories.length; i++) {
            _factoryOf[factories[i]] = true;
        }
    }

    function _v3Swap(
        address factory,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address[] calldata pools,
        address payer
    ) internal {
        // use amountIn == ActionConstants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (amountIn == ActionConstants.CONTRACT_BALANCE) {
            address tokenIn = path.decodeFirstToken();
            amountIn = IERC20(tokenIn).balanceOf(address(this));
        }

        uint256 amountOut;
        uint256 i = 0;

        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            // the outputs of prior swaps become the inputs to subsequent ones
            (int256 amount0Delta, int256 amount1Delta, bool zeroForOne) = _swap(
                amountIn.toInt256(),
                hasMultiplePools ? address(this) : recipient, // for intermediate swaps, this contract custodies
                path.getFirstPool(), // only the first pool is needed
                payer, // for intermediate swaps, this contract custodies
                factory,
                pools[i]
            );

            amountIn = uint256(-(zeroForOne ? amount1Delta : amount0Delta));

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                payer = address(this);
                path = path.skipToken();
            } else {
                amountOut = amountIn;
                break;
            }

            unchecked {
                ++i;
            }
        }

        if (amountOut < amountOutMinimum) revert SlippageIsTooLow(amountOut);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        _executeCallback(amount0Delta, amount1Delta, data);
    }

    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        _executeCallback(amount0Delta, amount1Delta, data);
    }

    function _executeCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) private {
        if (amount0Delta <= 0 && amount1Delta <= 0) revert InvalidAmount();
        (, address payer, address factory) = abi.decode(
            data,
            (bytes, address, address)
        );
        bytes calldata path = data.toBytes(0);
        (address tokenIn, uint24 fee, address tokenOut) = path
            .decodeFirstPool();

        /// @notice verify msg.sender
        address pool = IUniV3Factory(factory).getPool(tokenIn, tokenOut, fee);
        if (msg.sender != pool || !_factoryOf[factory]) revert InvalidPool();

        /// @dev Only exact input is supported
        uint256 amountToPay = amount0Delta > 0
            ? uint256(amount0Delta)
            : uint256(amount1Delta);
        payOrTransferFrom(tokenIn, payer, msg.sender, amountToPay);
    }

    /// @dev for AlgebraPool
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        if (amount0Delta <= 0 && amount1Delta <= 0) revert InvalidAmount();
        (, address payer, address factory) = abi.decode(
            data,
            (bytes, address, address)
        );
        bytes calldata path = data.toBytes(0);
        (address tokenIn, , address tokenOut) = path.decodeFirstPool();

        /// @notice verify msg.sender
        address pool = IUniV3Factory(factory).poolByPair(tokenIn, tokenOut);
        if (msg.sender != pool || !_factoryOf[factory]) revert InvalidPool();

        /// @dev Only exact input is supported
        uint256 amountToPay = amount0Delta > 0
            ? uint256(amount0Delta)
            : uint256(amount1Delta);
        payOrTransferFrom(tokenIn, payer, msg.sender, amountToPay);
    }

    function _swap(
        int256 amount,
        address recipient,
        bytes calldata path,
        address payer,
        address factory,
        address pool
    )
        private
        returns (int256 amount0Delta, int256 amount1Delta, bool zeroForOne)
    {
        (address tokenIn, , address tokenOut) = path.decodeFirstPool();
        zeroForOne = tokenIn < tokenOut;
        (amount0Delta, amount1Delta) = IUniV3Pool(pool).swap(
            recipient,
            zeroForOne,
            amount,
            (
                zeroForOne
                    ? TickMath.MIN_SQRT_RATIO + 1
                    : TickMath.MAX_SQRT_RATIO - 1
            ),
            abi.encode(path, payer, factory)
        );
    }
}
