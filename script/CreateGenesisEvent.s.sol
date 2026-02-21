// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RuneraEventRegistry} from "../src/RuneraEventRegistry.sol";
import {IRuneraEventRegistry} from "../src/interfaces/IRuneraEventRegistry.sol";

/**
 * @title CreateGenesisEvent
 * @notice Script to create the Genesis 10K event
 */
contract CreateGenesisEvent is Script {
    // Update these addresses after deployment
    address constant EVENT_REGISTRY = address(0); // Replace with deployed address

    function run() external {
        // Event Manager's private key (Anvil account #3)
        uint256 eventManagerKey = vm.envOr(
            "EVENT_MANAGER_KEY",
            uint256(
                0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
            )
        );

        vm.startBroadcast(eventManagerKey);

        RuneraEventRegistry registry = RuneraEventRegistry(EVENT_REGISTRY);

        // Genesis 10K Event ID
        bytes32 genesisEventId = keccak256("GENESIS_10K");

        // Create Genesis 10K event
        // Active from January 1, 2026 to December 31, 2026
        // Build empty reward (no reward for genesis event)
        uint256[] memory noCosmetics = new uint256[](0);
        IRuneraEventRegistry.EventReward memory noReward = IRuneraEventRegistry
            .EventReward({
                achievementTier: 0,
                cosmeticItemIds: noCosmetics,
                xpBonus: 0,
                hasReward: false
            });

        registry.createEvent(
            genesisEventId,
            "Genesis 10K",
            1735689600, // January 1, 2026 00:00:00 UTC
            1767225599, // December 31, 2026 23:59:59 UTC
            10000, // Max 10,000 participants
            noReward
        );

        console.log("Genesis 10K event created!");
        console.log("Event ID:", vm.toString(genesisEventId));

        vm.stopBroadcast();
    }
}
