// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";
import {RuneraEventRegistry} from "../src/RuneraEventRegistry.sol";
import {IRuneraEventRegistry} from "../src/interfaces/IRuneraEventRegistry.sol";

contract RuneraEventRegistryTest is Test {
    // Redeclare events for expectEmit (Solidity limitation)
    event EventCreated(
        bytes32 indexed eventId,
        string name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants
    );
    event EventRewardConfigured(
        bytes32 indexed eventId,
        uint8 achievementTier,
        uint256[] cosmeticItemIds,
        uint96 xpBonus
    );

    RuneraAccessControl public accessControl;
    RuneraEventRegistry public eventRegistry;

    address public admin = address(1);
    address public eventManager = address(2);
    address public randomUser = address(3);

    bytes32 public testEventId = keccak256("TEST_EVENT");

    // Helper: empty reward (no reward)
    function _noReward()
        internal
        pure
        returns (IRuneraEventRegistry.EventReward memory)
    {
        uint256[] memory empty = new uint256[](0);
        return
            IRuneraEventRegistry.EventReward({
                achievementTier: 0,
                cosmeticItemIds: empty,
                xpBonus: 0,
                hasReward: false
            });
    }

    // Helper: full reward
    function _fullReward()
        internal
        pure
        returns (IRuneraEventRegistry.EventReward memory)
    {
        uint256[] memory cosmetics = new uint256[](2);
        cosmetics[0] = 42;
        cosmetics[1] = 7;
        return
            IRuneraEventRegistry.EventReward({
                achievementTier: 3,
                cosmeticItemIds: cosmetics,
                xpBonus: 500,
                hasReward: true
            });
    }

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

    // ─── createEvent (no reward) ─────────────────────────────────────────────

    function test_CreateEvent() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            startTime,
            endTime,
            1000,
            _noReward()
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

    function test_CreateEventNoReward_RewardIsEmpty() public {
        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "No Reward Event",
            block.timestamp,
            block.timestamp + 30 days,
            100,
            _noReward()
        );

        IRuneraEventRegistry.EventReward memory reward = eventRegistry
            .getEventReward(testEventId);
        assertFalse(reward.hasReward);
        assertEq(reward.achievementTier, 0);
        assertEq(reward.cosmeticItemIds.length, 0);
        assertEq(reward.xpBonus, 0);
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
            1000,
            _noReward()
        );
    }

    // ─── createEvent (with reward) ────────────────────────────────────────────

    function test_CreateEventWithReward() public {
        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Reward Event",
            block.timestamp,
            block.timestamp + 30 days,
            500,
            _fullReward()
        );

        IRuneraEventRegistry.EventReward memory reward = eventRegistry
            .getEventReward(testEventId);
        assertTrue(reward.hasReward);
        assertEq(reward.achievementTier, 3);
        assertEq(reward.cosmeticItemIds.length, 2);
        assertEq(reward.cosmeticItemIds[0], 42);
        assertEq(reward.cosmeticItemIds[1], 7);
        assertEq(reward.xpBonus, 500);
    }

    function test_CreateEventWithReward_EmitsRewardEvent() public {
        uint256[] memory cosmetics = new uint256[](2);
        cosmetics[0] = 42;
        cosmetics[1] = 7;

        vm.prank(eventManager);
        vm.expectEmit(true, false, false, true);
        emit EventRewardConfigured(testEventId, 3, cosmetics, 500);
        eventRegistry.createEvent(
            testEventId,
            "Reward Event",
            block.timestamp,
            block.timestamp + 30 days,
            500,
            _fullReward()
        );
    }

    function test_CreateEventWithAchievementOnlyReward() public {
        uint256[] memory empty = new uint256[](0);
        IRuneraEventRegistry.EventReward memory reward = IRuneraEventRegistry
            .EventReward({
                achievementTier: 5, // Diamond
                cosmeticItemIds: empty,
                xpBonus: 1000,
                hasReward: true
            });

        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Achievement Only",
            block.timestamp,
            block.timestamp + 30 days,
            0,
            reward
        );

        IRuneraEventRegistry.EventReward memory stored = eventRegistry
            .getEventReward(testEventId);
        assertEq(stored.achievementTier, 5);
        assertEq(stored.cosmeticItemIds.length, 0);
        assertTrue(stored.hasReward);
    }

    function test_CreateEventInvalidTier_Reverts() public {
        uint256[] memory empty = new uint256[](0);
        IRuneraEventRegistry.EventReward memory badReward = IRuneraEventRegistry
            .EventReward({
                achievementTier: 6, // Invalid (max is 5)
                cosmeticItemIds: empty,
                xpBonus: 0,
                hasReward: true
            });

        vm.prank(eventManager);
        vm.expectRevert(RuneraEventRegistry.InvalidRewardTier.selector);
        eventRegistry.createEvent(
            testEventId,
            "Bad Event",
            block.timestamp,
            block.timestamp + 30 days,
            100,
            badReward
        );
    }

    // ─── setEventReward ───────────────────────────────────────────────────────

    function test_SetEventReward_AfterCreation() public {
        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Event",
            block.timestamp,
            block.timestamp + 30 days,
            100,
            _noReward()
        );

        eventRegistry.setEventReward(testEventId, _fullReward());
        vm.stopPrank();

        IRuneraEventRegistry.EventReward memory reward = eventRegistry
            .getEventReward(testEventId);
        assertTrue(reward.hasReward);
        assertEq(reward.achievementTier, 3);
        assertEq(reward.xpBonus, 500);
    }

    function test_SetEventReward_UpdateExistingReward() public {
        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Event",
            block.timestamp,
            block.timestamp + 30 days,
            100,
            _fullReward()
        );

        // Update to tier 5
        uint256[] memory newCosmetics = new uint256[](1);
        newCosmetics[0] = 99;
        IRuneraEventRegistry.EventReward
            memory updatedReward = IRuneraEventRegistry.EventReward({
                achievementTier: 5,
                cosmeticItemIds: newCosmetics,
                xpBonus: 2000,
                hasReward: true
            });
        eventRegistry.setEventReward(testEventId, updatedReward);
        vm.stopPrank();

        IRuneraEventRegistry.EventReward memory stored = eventRegistry
            .getEventReward(testEventId);
        assertEq(stored.achievementTier, 5);
        assertEq(stored.cosmeticItemIds[0], 99);
        assertEq(stored.xpBonus, 2000);
    }

    function test_SetEventReward_NonExistentEvent_Reverts() public {
        vm.prank(eventManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuneraEventRegistry.EventDoesNotExist.selector,
                testEventId
            )
        );
        eventRegistry.setEventReward(testEventId, _fullReward());
    }

    function test_SetEventReward_NonManager_Reverts() public {
        vm.prank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Event",
            block.timestamp,
            block.timestamp + 30 days,
            100,
            _noReward()
        );

        vm.prank(randomUser);
        vm.expectRevert(RuneraEventRegistry.NotEventManager.selector);
        eventRegistry.setEventReward(testEventId, _fullReward());
    }

    function test_SetEventReward_InvalidTier_Reverts() public {
        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Event",
            block.timestamp,
            block.timestamp + 30 days,
            100,
            _noReward()
        );

        uint256[] memory empty = new uint256[](0);
        IRuneraEventRegistry.EventReward memory badReward = IRuneraEventRegistry
            .EventReward({
                achievementTier: 6,
                cosmeticItemIds: empty,
                xpBonus: 0,
                hasReward: true
            });

        vm.expectRevert(RuneraEventRegistry.InvalidRewardTier.selector);
        eventRegistry.setEventReward(testEventId, badReward);
        vm.stopPrank();
    }

    // ─── Existing tests (updated signature) ──────────────────────────────────

    function test_CannotCreateDuplicateEvent() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;

        vm.startPrank(eventManager);
        eventRegistry.createEvent(
            testEventId,
            "Test Event",
            startTime,
            endTime,
            1000,
            _noReward()
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
            500,
            _noReward()
        );
        vm.stopPrank();
    }

    function test_CannotCreateEventWithInvalidTimeWindow() public {
        vm.prank(eventManager);
        vm.expectRevert(RuneraEventRegistry.InvalidTimeWindow.selector);
        eventRegistry.createEvent(
            testEventId,
            "Invalid Event",
            block.timestamp + 30 days,
            block.timestamp,
            1000,
            _noReward()
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
            1000,
            _noReward()
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
            1000,
            _noReward()
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
            1000,
            _noReward()
        );

        assertTrue(eventRegistry.isEventActive(testEventId));

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
            1000,
            _noReward()
        );

        assertFalse(eventRegistry.isEventActive(testEventId));

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
            1000,
            _noReward()
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
            10,
            _noReward()
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
            2,
            _noReward()
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
            0,
            _noReward()
        );
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
            1000,
            _noReward()
        );
        assertEq(eventRegistry.getEventCount(), 1);

        bytes32 event2 = keccak256("EVENT_2");
        eventRegistry.createEvent(
            event2,
            "Event 2",
            block.timestamp,
            block.timestamp + 30 days,
            1000,
            _noReward()
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
            1000,
            _noReward()
        );
        assertEq(eventRegistry.getEventIdByIndex(0), testEventId);
    }
}
