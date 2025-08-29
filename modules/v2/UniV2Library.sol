// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeTransferLib} from "../../libraries/SafeTransferLib.sol";
import {IUniV2Factory, IUniV2Pool} from "../../interfaces/IUniV2.sol";
import {InsufficientLiquidity, InsufficientAmount} from "../../libraries/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library UniV2Library {
    using SafeTransferLib for address;

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        if (amountA == 0) revert InsufficientAmount();
        if (reserveA == 0 || reserveB == 0) revert InsufficientLiquidity();
        amountB = (amountA * reserveB) / reserveA;
    }

    function sortToken0(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0) {
        token0 = tokenA < tokenB ? tokenA : tokenB;
    }

    function pairAndToken0For(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (address pair, address token0) {
        token0 = sortToken0(tokenA, tokenB);
        pair = IUniV2Factory(factory).getPair(tokenA, tokenB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint16 swapFee
    ) internal pure returns (uint256 amountOut) {
        unchecked {
            uint256 amountInWithFee = amountIn * swapFee;
            uint256 numerator = amountInWithFee * reserveOut;
            uint256 denominator = reserveIn * 10_000 + amountInWithFee;
            amountOut = numerator / denominator;
        }
    }

    function addLiquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (address pair, uint256 amountA, uint256 amountB) {
        pair = IUniV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IUniV2Factory(factory).createPair(tokenA, tokenB);
        }

        /// @dev bug from https://blog.alphaventuredao.io/mev-bots-uniswap-implicit-assumptions/
        assert(amountADesired >= amountAMin && amountBDesired >= amountBMin);

        (uint256 reserve0, uint256 reserve1) = IUniV2Pool(pair).getReserves();
        (uint256 reserveA, uint256 reserveB) = tokenA < tokenB
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert InsufficientAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                if (amountAOptimal < amountAMin) revert InsufficientAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function removeLiquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        address to
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = IUniV2Factory(factory).getPair(tokenA, tokenB);
        pair.safeTransferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = IUniV2Pool(pair).burn(to);
        (amountA, amountB) = tokenA < tokenB
            ? (amount0, amount1)
            : (amount1, amount0);
    }

    function swap(
        address factory,
        uint16[] calldata swapFees,
        address[] calldata path,
        address recipient,
        address pair
    ) internal {
        unchecked {
            address token0 = sortToken0(path[0], path[1]);
            uint256 finalPairIndex = path.length - 1;
            uint256 penultimatePairIndex = finalPairIndex - 1;
            for (uint256 i; i < finalPairIndex; i++) {
                (address input, address output) = (path[i], path[i + 1]);
                (uint256 reserve0, uint256 reserve1) = IUniV2Pool(pair)
                    .getReserves();
                (uint256 reserveIn, uint256 reserveOut) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                uint256 amountIn = IERC20(input).balanceOf(pair) - reserveIn;
                uint256 amountOut = getAmountOut(
                    amountIn,
                    reserveIn,
                    reserveOut,
                    swapFees[i]
                );
                (uint256 amount0Out, uint256 amount1Out) = input == token0
                    ? (uint256(0), amountOut)
                    : (amountOut, uint256(0));
                address nextPair;
                (nextPair, token0) = i < penultimatePairIndex
                    ? pairAndToken0For(factory, output, path[i + 2])
                    : (recipient, address(0));
                IUniV2Pool(pair).swap(
                    amount0Out,
                    amount1Out,
                    nextPair,
                    new bytes(0)
                );
                pair = nextPair;
            }
        }
    }
}
