// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IReferrerCaller {
    error NotCaller();

    function setReferrer(address referrer, address user) external;
}
