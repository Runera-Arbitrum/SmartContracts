// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IRuneraAccessControl} from "../interfaces/IRuneraAccessControl.sol";

/**
 * @title RuneraAccessControl
 * @notice Centralized access control for the Runera ecosystem
 * @dev Extends OpenZeppelin AccessControl with custom roles
 */
contract RuneraAccessControl is AccessControl, IRuneraAccessControl {
    /// @notice Role for administrators who can manage other roles
    bytes32 public constant override ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    /// @notice Role for backend signers who can authorize operations
    bytes32 public constant override BACKEND_SIGNER_ROLE =
        keccak256("BACKEND_SIGNER_ROLE");

    /// @notice Role for event managers who can create/update events
    bytes32 public constant override EVENT_MANAGER_ROLE =
        keccak256("EVENT_MANAGER_ROLE");

    /**
     * @notice Initializes the access control with deployer as admin
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @inheritdoc IRuneraAccessControl
     */
    function grantRole(
        bytes32 role,
        address account
    ) public override(AccessControl, IRuneraAccessControl) {
        _checkRole(getRoleAdmin(role), _msgSender());
        _grantRole(role, account);
    }

    /**
     * @inheritdoc IRuneraAccessControl
     */
    function revokeRole(
        bytes32 role,
        address account
    ) public override(AccessControl, IRuneraAccessControl) {
        _checkRole(getRoleAdmin(role), _msgSender());
        _revokeRole(role, account);
    }

    /**
     * @inheritdoc IRuneraAccessControl
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view override(AccessControl, IRuneraAccessControl) returns (bool) {
        return super.hasRole(role, account);
    }

    /**
     * @notice Check if an account is a backend signer
     * @param account The address to check
     * @return True if the account has BACKEND_SIGNER_ROLE
     */
    function isBackendSigner(address account) external view returns (bool) {
        return hasRole(BACKEND_SIGNER_ROLE, account);
    }

    /**
     * @notice Check if an account is an event manager
     * @param account The address to check
     * @return True if the account has EVENT_MANAGER_ROLE
     */
    function isEventManager(address account) external view returns (bool) {
        return hasRole(EVENT_MANAGER_ROLE, account);
    }

    /**
     * @notice Check if an account is an admin
     * @param account The address to check
     * @return True if the account has ADMIN_ROLE
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }
}
