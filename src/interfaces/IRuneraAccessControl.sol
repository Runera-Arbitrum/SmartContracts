// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRuneraAccessControl
 * @notice Interface for Runera access control system
 */
interface IRuneraAccessControl {
    /// @notice Role constants
    function ADMIN_ROLE() external view returns (bytes32);
    function BACKEND_SIGNER_ROLE() external view returns (bytes32);
    function EVENT_MANAGER_ROLE() external view returns (bytes32);

    /// @notice Check if an account has a specific role
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    /// @notice Grant a role to an account (ADMIN only)
    function grantRole(bytes32 role, address account) external;

    /// @notice Revoke a role from an account (ADMIN only)
    function revokeRole(bytes32 role, address account) external;
}
