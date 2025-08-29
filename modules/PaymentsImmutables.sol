// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import {IWETH9} from "../interfaces/IWETH9.sol";

contract PaymentsImmutables {
    IWETH9 internal immutable WETH9;

    constructor(IWETH9 weth9) {
        WETH9 = weth9;
    }
}
