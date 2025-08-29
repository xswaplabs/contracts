// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IUniV2Factory, IUniV2Pool} from "../../interfaces/IUniV2.sol";
import {SafeTransferLib} from "../../libraries/SafeTransferLib.sol";
import {UniV2Library} from "./UniV2Library.sol";
import {InsufficientAmount, SlippageIsTooLow} from "../../libraries/Errors.sol";
import {Constants} from "../../libraries/Constants.sol";
import {Payments} from "../Payments.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract V2SwapRouter is Payments {
    using SafeTransferLib for address;

    function _v2Swap(
        address factory,
        uint16[] calldata swapFees,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address payer
    ) internal {
        address firstPair = IUniV2Factory(factory).getPair(path[0], path[1]);
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrTransferFrom(path[0], payer, firstPair, amountIn);
        }

        IERC20 tokenOut = IERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        UniV2Library.swap(factory, swapFees, path, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert SlippageIsTooLow(amountOut);
    }

    function addV2Liquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external {
        (address pair, uint256 amountA, uint256 amountB) = UniV2Library
            .addLiquidity(
                factory,
                tokenA,
                tokenB,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin
            );
        tokenA.safeTransferFrom(msg.sender, pair, amountA);
        tokenB.safeTransferFrom(msg.sender, pair, amountB);
        IUniV2Pool(pair).mint(msg.sender);
    }

    function addV2LiquidityETH(
        address factory,
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin
    ) external payable {
        (address pair, uint256 amountToken, uint256 amountETH) = UniV2Library
            .addLiquidity(
                factory,
                token,
                address(WETH9),
                amountTokenDesired,
                msg.value,
                amountTokenMin,
                amountETHMin
            );
        token.safeTransferFrom(msg.sender, pair, amountToken);
        WETH9.deposit{value: amountETH}();
        WETH9.transfer(pair, amountETH);
        IUniV2Pool(pair).mint(msg.sender);
        unchecked {
            if (msg.value > amountETH)
                msg.sender.safeTransferETH(msg.value - amountETH);
        }
    }

    function removeV2Liquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external {
        (uint256 amountA, uint256 amountB) = UniV2Library.removeLiquidity(
            factory,
            tokenA,
            tokenB,
            liquidity,
            msg.sender
        );
        if (amountA < amountAMin) revert InsufficientAmount();
        if (amountB < amountBMin) revert InsufficientAmount();
    }

    function removeV2LiquidityETH(
        address factory,
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin
    ) external {
        UniV2Library.removeLiquidity(
            factory,
            token,
            address(WETH9),
            liquidity,
            address(this)
        );
        uint256 amountToken = IERC20(token).balanceOf(address(this));
        uint256 amountETH = WETH9.balanceOf(address(this));
        if (amountToken < amountTokenMin) revert InsufficientAmount();
        if (amountETH < amountETHMin) revert InsufficientAmount();
        token.safeTransfer(msg.sender, amountToken);
        WETH9.withdraw(amountETH);
        msg.sender.safeTransferETH(amountETH);
    }
}
