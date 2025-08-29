// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUniV3Callback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external;

    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external;

    /// @dev for AlgebraPool
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external;
}
