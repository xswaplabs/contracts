// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUniV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniV2Pool {
    /// @dev lite interface for getReserves
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function mint(address to) external returns (uint256 liquidity);

    function burn(
        address to
    ) external returns (uint256 amount0, uint256 amount1);
}
