// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

library Constants {
    uint256 internal constant ADDR_SIZE = 20;

    uint256 internal constant V3_FEE_SIZE = 3;

    uint256 internal constant NEXT_V3_POOL_OFFSET = ADDR_SIZE + V3_FEE_SIZE;

    uint256 internal constant V3_POP_OFFSET = NEXT_V3_POOL_OFFSET + ADDR_SIZE;

    uint256 internal constant MULTIPLE_V3_POOLS_MIN_LENGTH =
        V3_POP_OFFSET + NEXT_V3_POOL_OFFSET;

    /// @dev Used to identify the token address for ETH
    address internal constant ETH = address(0);

    /// @dev Used to identify that the v2 pool has already received the input token
    uint256 internal constant ALREADY_PAID = 0;
}
