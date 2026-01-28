// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";

contract RuneraAccessControlTest is Test {
    RuneraAccessControl public accessControl;

    address public admin;
    address public backendSigner;
    address public eventManager;
    address public randomUser;

    // Event declarations for testing
    // Matching OpenZeppelin AccessControl events
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    // Explicitly define the error from OpenZeppelin AccessControl
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        admin = makeAddr("admin");
        backendSigner = makeAddr("backendSigner");
        eventManager = makeAddr("eventManager");
        randomUser = makeAddr("randomUser");

        vm.startPrank(admin);
        accessControl = new RuneraAccessControl();
        vm.stopPrank();
    }

    function test_DeployerIsAdmin() public view {
        assertTrue(accessControl.hasRole(accessControl.ADMIN_ROLE(), admin));
        assertTrue(accessControl.isAdmin(admin));
    }

    function test_GrantBackendSignerRole() public {
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        vm.stopPrank();

        assertTrue(
            accessControl.hasRole(
                accessControl.BACKEND_SIGNER_ROLE(),
                backendSigner
            )
        );
        assertTrue(accessControl.isBackendSigner(backendSigner));
    }

    function test_GrantEventManagerRole() public {
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.EVENT_MANAGER_ROLE(),
            eventManager
        );
        vm.stopPrank();

        assertTrue(
            accessControl.hasRole(
                accessControl.EVENT_MANAGER_ROLE(),
                eventManager
            )
        );
        assertTrue(accessControl.isEventManager(eventManager));
    }

    function test_RevokeRole() public {
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        assertTrue(accessControl.isBackendSigner(backendSigner));

        accessControl.revokeRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        vm.stopPrank();
        assertFalse(accessControl.isBackendSigner(backendSigner));
    }

    function test_NonAdminCannotGrantRole() public {
        vm.startPrank(randomUser);
        console.log("Random User:", randomUser);
        bytes32 adminRole = accessControl.DEFAULT_ADMIN_ROLE();
        console.log(
            "Has Admin Role:",
            accessControl.hasRole(adminRole, randomUser)
        );
        console.log("Is Admin (via func):", accessControl.isAdmin(randomUser));

        bytes32 roleToGrant = accessControl.BACKEND_SIGNER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                randomUser,
                accessControl.DEFAULT_ADMIN_ROLE()
            )
        );
        accessControl.grantRole(roleToGrant, backendSigner);
        vm.stopPrank();
    }

    function test_NonAdminCannotRevokeRole() public {
        // Setup: Admin grants role
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        vm.stopPrank();

        // Test: Random user tries to revoke
        vm.startPrank(randomUser);
        bytes32 roleToRevoke = accessControl.BACKEND_SIGNER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                randomUser,
                accessControl.DEFAULT_ADMIN_ROLE()
            )
        );
        accessControl.revokeRole(roleToRevoke, backendSigner);
        vm.stopPrank();
    }

    function test_RoleConstants() public view {
        assertEq(accessControl.ADMIN_ROLE(), bytes32(0));
        assertEq(
            accessControl.BACKEND_SIGNER_ROLE(),
            keccak256("BACKEND_SIGNER_ROLE")
        );
        assertEq(
            accessControl.EVENT_MANAGER_ROLE(),
            keccak256("EVENT_MANAGER_ROLE")
        );
    }

    function test_EmitRoleGrantedEvent() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner,
            admin
        );
        accessControl.grantRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        vm.stopPrank();
    }

    function test_EmitRoleRevokedEvent() public {
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );

        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner,
            admin
        );
        accessControl.revokeRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        vm.stopPrank();
    }
}
