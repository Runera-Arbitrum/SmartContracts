// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RuneraEventRegistry} from "../src/RuneraEventRegistry.sol";

/**
 * @title DeployEventRegistry
 * @notice Redeploy only RuneraEventRegistry (e.g. after adding EventReward config)
 * @dev Uses existing AccessControl — no need to redeploy other contracts
 */
contract DeployEventRegistry is Script {
    function run() external {
        address accessControl = vm.envAddress("ACCESS_CONTROL_ADDRESS");

        vm.startBroadcast();

        console.log("=== Deploying RuneraEventRegistry ===");
        console.log("AccessControl:", accessControl);

        RuneraEventRegistry eventRegistry = new RuneraEventRegistry(
            accessControl
        );

        console.log("EventRegistry deployed at:", address(eventRegistry));
        console.log("");
        console.log("Update .env:");
        console.log("EVENT_REGISTRY_ADDRESS=", address(eventRegistry));

        vm.stopBroadcast();
    }
}
