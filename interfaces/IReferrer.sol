// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IReferrer {
    event SetReferrer(address user, address referrer);
    event SetProbability(address referrer, uint16 probability);
    event SetCaller(address caller, bool ok);

    error ReferrerAlreadySet();
    error InvalidReferrer();

    /// @dev user info
    struct UserInfo {
        address owner;
        uint256 count;
        uint16 probability;
        bool isContract;
    }

    /// @dev get user info
    function getUser(address user) external view returns (UserInfo memory);

    /// @dev get referrer info for a user
    function getReferrer(address user) external view returns (UserInfo memory);
}
