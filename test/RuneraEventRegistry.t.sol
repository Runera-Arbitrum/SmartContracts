// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";
import {RuneraEventRegistry} from "../src/RuneraEventRegistry.sol";
import {IRuneraEventRegistry} from "../src/interfaces/IRuneraEventRegistry.sol";

contract RuneraEventRegistryTest is Test {
    // Redeclare event for expectEmit (Solidity limitation: can't reference interface events directly)
    event EventCreated(
        bytes32 indexed eventId,
        string name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants
    );

    RuneraAccessControl public accessControl;
    RuneraEventRegistry public eventRegistry;

    address public admin = address(1);
    address public eventManager = address(2);
    address public randomUser = address(3);

    bytes32 public testEventId = keccak256("TEST_EVENT");

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new RuneraAccessControl();
        eventRegistry = new RuneraEventRegistry(address(accessControl));
        accessControl.grantRole(
            accessControl.EVENT_MANAGER_ROLE(),
            eventManager
        );
        vm.stopPrank();
    }

    function test_CreateEvent() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            startTime,
            endTime,
            1000
        );

        IRuneraEventRegistry.EventConfig memory config = eventRegistry.getEvent(
            testEventId
        );
        assertEq(config.eventId, testEventId);
        assertEq(config.name, "Test Event");
        assertEq(config.startTime, startTime);
        assertEq(config.endTime, endTime);
        assertEq(config.maxParticipants, 1000);
        assertEq(config.currentParticipants, 0);
        assertTrue(config.active);
    }

    function test_CreateEventEmitsEvent() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        vm.prank(eventManager);
        vm.expectEmit(true, false, false, true);
        emit EventCreated(testEventId, "Test Event", startTime, endTime, 1000);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            startTime,
            endTime,
            1000
        );
    }

    function test_CannotCreateDuplicateEvent() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            startTime,
            endTime,
            1000
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                RuneraEventRegistry.EventAlreadyExists.selector,
                testEventId
            )
        );
        eventRegistry.createEvent(
            testEventId,
            "Duplicate Event",
            startTime,
            endTime,
            500
        );
        vm.stopPrank();
    }

    function test_CannotCreateEventWithInvalidTimeWindow() public {
        uint256 startTime = block.timestamp + 30 days;
        uint256 endTime = block.timestamp; // End before start

        vm.prank(eventManager);
        vm.expectRevert(RuneraEventRegistry.InvalidTimeWindow.selector);
        eventRegistry.createEvent(
            testEventId,
            "Invalid Event",
            startTime,
            endTime,
            1000
        );
    }

    function test_NonEventManagerCannotCreateEvent() public {
        vm.prank(randomUser);
        vm.expectRevert(RuneraEventRegistry.NotEventManager.selector);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            block.timestamp,
            block.timestamp + 30 days,
            1000
        );
    }

    function test_UpdateEvent() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            startTime,
            endTime,
            1000
        );

        uint256 newEndTime = block.timestamp + 60 days;
        eventRegistry.updateEvent(
            testEventId,
            "Updated Event",
            startTime,
            newEndTime,
            2000,
            true
        );
        vm.stopPrank();

        IRuneraEventRegistry.EventConfig memory config = eventRegistry.getEvent(
            testEventId
        );
        assertEq(config.name, "Updated Event");
        assertEq(config.endTime, newEndTime);
        assertEq(config.maxParticipants, 2000);
    }

    function test_UpdateNonExistentEvent() public {
        vm.prank(eventManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuneraEventRegistry.EventDoesNotExist.selector,
                testEventId
            )
        );
        eventRegistry.updateEvent(
            testEventId,
            "Updated Event",
            block.timestamp,
            block.timestamp + 30 days,
            1000,
            true
        );
    }

    function test_IsEventActive() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            startTime,
            endTime,
            1000
        );

        assertTrue(eventRegistry.isEventActive(testEventId));

        // Warp past end time
        vm.warp(endTime + 1);
        assertFalse(eventRegistry.isEventActive(testEventId));
    }

    function test_IsEventActiveBeforeStart() public {
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 30 days;

        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Future Event",
            startTime,
            endTime,
            1000
        );

        assertFalse(eventRegistry.isEventActive(testEventId));

        // Warp to start time
        vm.warp(startTime);
        assertTrue(eventRegistry.isEventActive(testEventId));
    }

    function test_EventExists() public {
        assertFalse(eventRegistry.eventExists(testEventId));

        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            block.timestamp,
            block.timestamp + 30 days,
            1000
        );

        assertTrue(eventRegistry.eventExists(testEventId));
    }

    function test_IncrementParticipants() public {
        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            block.timestamp,
            block.timestamp + 30 days,
            10
        );

        eventRegistry.incrementParticipants(testEventId);
        vm.stopPrank();

        IRuneraEventRegistry.EventConfig memory config = eventRegistry.getEvent(
            testEventId
        );
        assertEq(config.currentParticipants, 1);
    }

    function test_EventFullPreventsMoreParticipants() public {
        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Small Event",
            block.timestamp,
            block.timestamp + 30 days,
            2 // Only 2 spots
        );

        eventRegistry.incrementParticipants(testEventId);
        eventRegistry.incrementParticipants(testEventId);

        vm.expectRevert(RuneraEventRegistry.EventFull.selector);
        eventRegistry.incrementParticipants(testEventId);
        vm.stopPrank();
    }

    function test_UnlimitedParticipants() public {
        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Unlimited Event",
            block.timestamp,
            block.timestamp + 30 days,
            0 // Unlimited
        );

        // Should not revert even after many participants
        for (uint256 i = 0; i < 100; i++) {
            eventRegistry.incrementParticipants(testEventId);
        }
        vm.stopPrank();

        IRuneraEventRegistry.EventConfig memory config = eventRegistry.getEvent(
            testEventId
        );
        assertEq(config.currentParticipants, 100);
    }

    function test_GetEventCount() public {
        assertEq(eventRegistry.getEventCount(), 0);

        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Event 1",
            block.timestamp,
            block.timestamp + 30 days,
            1000
        );
        assertEq(eventRegistry.getEventCount(), 1);

        bytes32 event2 = keccak256("EVENT_2");
        eventRegistry.createEvent(
            event2,
            "Event 2",
            block.timestamp,
            block.timestamp + 30 days,
            1000
        );
        assertEq(eventRegistry.getEventCount(), 2);
        vm.stopPrank();
    }

    function test_GetEventIdByIndex() public {
        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            block.timestamp,
            block.timestamp + 30 days,
            1000
        );

        assertEq(eventRegistry.getEventIdByIndex(0), testEventId);
    }
}
