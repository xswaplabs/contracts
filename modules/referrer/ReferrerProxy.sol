// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IReferrerCaller} from "../../interfaces/IReferrerCaller.sol";

abstract contract ReferrerProxy {
    address internal immutable REFERRER;

    constructor(address _referrer) {
        REFERRER = _referrer;
    }

    function setReferrer(address referrer, address user) internal {
        IReferrerCaller(REFERRER).setReferrer(referrer, user);
    }
}
