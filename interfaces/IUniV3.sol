// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUniV3Quoter {
    function quoteExactInput(
        address factory,
        bytes memory path,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 priceImpact);
}

interface IUniV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /// @dev for AlgebraPool
    function poolByPair(
        address tokenA,
        address tokenB
    ) external view returns (address pool);
}

interface IUniV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}
