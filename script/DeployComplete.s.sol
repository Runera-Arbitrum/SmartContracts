// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";
import {RuneraEventRegistry} from "../src/RuneraEventRegistry.sol";
import {RuneraProfileDynamicNFT} from "../src/RuneraProfileDynamicNFT.sol";
import {
    RuneraAchievementDynamicNFT
} from "../src/RuneraAchievementDynamicNFT.sol";
import {RuneraCosmeticNFT} from "../src/RuneraCosmeticNFT.sol";
import {RuneraMarketplace} from "../src/RuneraMarketplace.sol";

/**
 * @title DeployComplete
 * @notice Deployment script for complete Runera 3-layer identity protocol
 * @dev Deploys all 6 core contracts in correct order
 */
contract DeployComplete is Script {
    // Metadata URIs (update for production)
    string constant PROFILE_BASE_URI = "https://api.runera.xyz/profile/";
    string constant ACHIEVEMENT_BASE_URI =
        "https://api.runera.xyz/achievement/";
    string constant COSMETIC_BASE_URI = "https://api.runera.xyz/cosmetic/";

    // Test accounts (from .env)
    address public deployer;
    address public backendSigner;
    address public eventManager;

    // Deployed contracts
    RuneraAccessControl public accessControl;
    RuneraEventRegistry public eventRegistry;
    RuneraProfileDynamicNFT public profileNft;
    RuneraAchievementDynamicNFT public achievementNft;
    RuneraCosmeticNFT public cosmeticNft;
    RuneraMarketplace public marketplace;

    function setUp() public {
        // Load from environment
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        backendSigner = vm.envOr("BACKEND_SIGNER_ADDRESS", deployer);
        eventManager = vm.envOr("EVENT_MANAGER_ADDRESS", deployer);
    }

    function run() public {
        vm.startBroadcast();

        console.log("=== Deploying Runera Complete Protocol ===");
        console.log("Deployer:", deployer);
        console.log("");

        // 1. Deploy Access Control
        console.log("1/6 Deploying Access Control...");
        accessControl = new RuneraAccessControl();
        console.log("   AccessControl:", address(accessControl));

        // 2. Deploy Event Registry
        console.log("2/6 Deploying Event Registry...");
        eventRegistry = new RuneraEventRegistry(address(accessControl));
        console.log("   EventRegistry:", address(eventRegistry));

        // 3. Deploy Profile Dynamic NFT
        console.log("3/6 Deploying Profile Dynamic NFT...");
        profileNft = new RuneraProfileDynamicNFT(
            address(accessControl),
            PROFILE_BASE_URI
        );
        console.log("   ProfileDynamicNFT:", address(profileNft));

        // 4. Deploy Achievement Dynamic NFT
        console.log("4/6 Deploying Achievement Dynamic NFT...");
        achievementNft = new RuneraAchievementDynamicNFT(
            address(accessControl),
            ACHIEVEMENT_BASE_URI
        );
        console.log("   AchievementDynamicNFT:", address(achievementNft));

        // 5. Deploy Cosmetic NFT
        console.log("5/6 Deploying Cosmetic NFT...");
        cosmeticNft = new RuneraCosmeticNFT(
            address(accessControl),
            COSMETIC_BASE_URI
        );
        console.log("   CosmeticNFT:", address(cosmeticNft));

        // 6. Deploy Marketplace
        console.log("6/6 Deploying Marketplace...");
        marketplace = new RuneraMarketplace(
            address(accessControl),
            address(cosmeticNft)
        );
        console.log("   Marketplace:", address(marketplace));

        console.log("");
        console.log("=== Granting Roles ===");

        // Grant Backend Signer role
        bytes32 backendSignerRole = accessControl.BACKEND_SIGNER_ROLE();
        accessControl.grantRole(backendSignerRole, backendSigner);
        console.log("Backend Signer role granted to:", backendSigner);

        // Grant Event Manager role
        bytes32 eventManagerRole = accessControl.EVENT_MANAGER_ROLE();
        accessControl.grantRole(eventManagerRole, eventManager);
        console.log("Event Manager role granted to:", eventManager);

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("");
        console.log("Contract Addresses:");
        console.log("-------------------");
        console.log("AccessControl:        ", address(accessControl));
        console.log("EventRegistry:        ", address(eventRegistry));
        console.log("ProfileDynamicNFT:    ", address(profileNft));
        console.log("AchievementDynamicNFT:", address(achievementNft));
        console.log("CosmeticNFT:          ", address(cosmeticNft));
        console.log("Marketplace:          ", address(marketplace));
        console.log("");
        console.log("Roles:");
        console.log("------");
        console.log("Admin:         ", deployer);
        console.log("Backend Signer:", backendSigner);
        console.log("Event Manager: ", eventManager);
        console.log("");
        console.log("3-Layer Protocol Status: COMPLETE");
        console.log("- Layer 1 (Identity):  ProfileDynamicNFT");
        console.log("- Layer 2 (Proof):     AchievementDynamicNFT");
        console.log("- Layer 3 (Economy):   CosmeticNFT + Marketplace");

        vm.stopBroadcast();
    }
}
