// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";
import {RuneraProfileDynamicNFT} from "../src/RuneraProfileDynamicNFT.sol";
import {IRuneraProfile} from "../src/interfaces/IRuneraProfile.sol";

contract RuneraProfileDynamicNFTTest is Test {
    RuneraAccessControl public accessControl;
    RuneraProfileDynamicNFT public profileNFT;

    address public admin = address(1);
    uint256 public backendSignerPrivateKey = 0x1234;
    address public backendSigner;

    address public user1 = address(10);
    address public user2 = address(20);

    string constant BASE_URI = "https://api.runera.xyz/profile/";

    // EIP-712 TypeHash (must match contract)
    bytes32 constant STATS_UPDATE_TYPEHASH =
        keccak256(
            "StatsUpdate(address user,uint96 xp,uint16 level,uint32 runCount,uint32 achievementCount,uint64 totalDistanceMeters,uint32 longestStreakDays,uint64 lastUpdated,uint256 nonce,uint256 deadline)"
        );

    // EIP-712 TypeHash for gasless registration (must match contract)
    bytes32 constant REGISTER_TYPEHASH =
        keccak256("Register(address user,uint256 nonce,uint256 deadline)");

    // Events
    event ProfileRegistered(address indexed user);
    event ProfileNFTMinted(address indexed user, uint256 tokenId, uint8 tier);
    event ProfileTierUpgraded(
        address indexed user,
        uint8 oldTier,
        uint8 newTier
    );
    event StatsUpdated(address indexed user, IRuneraProfile.ProfileStats stats);

    function setUp() public {
        backendSigner = vm.addr(backendSignerPrivateKey);

        // Deploy as admin
        vm.startPrank(admin);
        accessControl = new RuneraAccessControl();
        profileNFT = new RuneraProfileDynamicNFT(
            address(accessControl),
            BASE_URI
        );

        // Grant backend signer role
        accessControl.grantRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        vm.stopPrank();
    }

    // ========== Registration Tests ==========

    function test_Register() public {
        vm.prank(user1);
        profileNFT.register();

        assertTrue(profileNFT.hasProfile(user1));
    }

    function test_RegisterEmitsEvents() public {
        uint256 expectedTokenId = profileNFT.getTokenId(user1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, false);
        emit ProfileRegistered(user1);
        vm.expectEmit(true, false, false, true);
        emit ProfileNFTMinted(user1, expectedTokenId, 1); // Bronze tier
        profileNFT.register();
    }

    function test_RegisterMintsNFT() public {
        vm.prank(user1);
        profileNFT.register();

        uint256 tokenId = profileNFT.getTokenId(user1);
        assertEq(profileNFT.balanceOf(user1, tokenId), 1);
    }

    function test_CannotRegisterTwice() public {
        vm.startPrank(user1);
        profileNFT.register();

        vm.expectRevert(RuneraProfileDynamicNFT.AlreadyRegistered.selector);
        profileNFT.register();
        vm.stopPrank();
    }

    function test_GetProfileDefaultValues() public {
        vm.prank(user1);
        profileNFT.register();

        IRuneraProfile.ProfileData memory profile = profileNFT.getProfile(
            user1
        );
        assertEq(profile.xp, 0);
        assertEq(profile.level, 1);
        assertEq(profile.runCount, 0);
        assertEq(profile.achievementCount, 0);
        assertEq(profile.totalDistanceMeters, 0);
        assertEq(profile.longestStreakDays, 0);
        assertTrue(profile.exists);
    }

    // ========== Gasless Registration Tests ==========

    function test_RegisterFor_Success() public {
        uint256 userPrivateKey = 0x5678;
        address user = vm.addr(userPrivateKey);
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature = _signRegister(
            user,
            0,
            deadline,
            userPrivateKey
        );

        // Anyone can relay the transaction
        address relayer = address(0x999);
        vm.prank(relayer);
        profileNFT.registerFor(user, deadline, signature);

        assertTrue(profileNFT.hasProfile(user));
        assertEq(profileNFT.balanceOf(user, profileNFT.getTokenId(user)), 1);
    }

    function test_RegisterFor_EmitsEvents() public {
        uint256 userPrivateKey = 0x5678;
        address user = vm.addr(userPrivateKey);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 expectedTokenId = profileNFT.getTokenId(user);

        bytes memory signature = _signRegister(
            user,
            0,
            deadline,
            userPrivateKey
        );

        vm.expectEmit(true, false, false, false);
        emit ProfileRegistered(user);
        vm.expectEmit(true, false, false, true);
        emit ProfileNFTMinted(user, expectedTokenId, 1);
        profileNFT.registerFor(user, deadline, signature);
    }

    function test_RegisterFor_ExpiredSignature() public {
        uint256 userPrivateKey = 0x5678;
        address user = vm.addr(userPrivateKey);
        uint256 deadline = block.timestamp - 1; // Past deadline

        bytes memory signature = _signRegister(
            user,
            0,
            deadline,
            userPrivateKey
        );

        vm.expectRevert(RuneraProfileDynamicNFT.SignatureExpired.selector);
        profileNFT.registerFor(user, deadline, signature);
    }

    function test_RegisterFor_AlreadyRegistered() public {
        uint256 userPrivateKey = 0x5678;
        address user = vm.addr(userPrivateKey);
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature = _signRegister(
            user,
            0,
            deadline,
            userPrivateKey
        );
        profileNFT.registerFor(user, deadline, signature);

        // Try to register again with new signature
        bytes memory signature2 = _signRegister(
            user,
            1,
            deadline,
            userPrivateKey
        );

        vm.expectRevert(RuneraProfileDynamicNFT.AlreadyRegistered.selector);
        profileNFT.registerFor(user, deadline, signature2);
    }

    function test_RegisterFor_InvalidSigner() public {
        uint256 userPrivateKey = 0x5678;
        uint256 wrongPrivateKey = 0x9999;
        address user = vm.addr(userPrivateKey);
        uint256 deadline = block.timestamp + 1 hours;

        // Sign with wrong key
        bytes memory signature = _signRegister(
            user,
            0,
            deadline,
            wrongPrivateKey
        );

        vm.expectRevert(RuneraProfileDynamicNFT.InvalidSignature.selector);
        profileNFT.registerFor(user, deadline, signature);
    }

    function test_RegisterFor_NonceIncrements() public {
        uint256 userPrivateKey = 0x5678;
        address user = vm.addr(userPrivateKey);

        assertEq(profileNFT.getRegisterNonce(user), 0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signRegister(
            user,
            0,
            deadline,
            userPrivateKey
        );
        profileNFT.registerFor(user, deadline, signature);

        // Nonce should be incremented even though user is now registered
        assertEq(profileNFT.getRegisterNonce(user), 1);
    }

    // ========== Tier Calculation Tests ==========

    function test_TierCalculation_Bronze() public {
        vm.prank(user1);
        profileNFT.register();

        // Level 1-2 = Bronze (tier 1)
        assertEq(profileNFT.getProfileTier(user1), 1);
    }

    function test_TierCalculation_Silver() public {
        vm.prank(user1);
        profileNFT.register();

        // Update to level 3 = Silver (tier 2)
        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 300,
            level: 3,
            runCount: 5,
            achievementCount: 1,
            totalDistanceMeters: 5000,
            longestStreakDays: 3,
            lastUpdated: uint64(block.timestamp)
        });

        bytes memory signature = _signStatsUpdate(
            user1,
            stats,
            0,
            block.timestamp + 1 hours
        );
        profileNFT.updateStats(
            user1,
            stats,
            block.timestamp + 1 hours,
            signature
        );

        assertEq(profileNFT.getProfileTier(user1), 2);
    }

    function test_TierCalculation_Gold() public {
        vm.prank(user1);
        profileNFT.register();

        // Update to level 5 = Gold (tier 3)
        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 500,
            level: 5,
            runCount: 10,
            achievementCount: 2,
            totalDistanceMeters: 10000,
            longestStreakDays: 5,
            lastUpdated: uint64(block.timestamp)
        });

        bytes memory signature = _signStatsUpdate(
            user1,
            stats,
            0,
            block.timestamp + 1 hours
        );
        profileNFT.updateStats(
            user1,
            stats,
            block.timestamp + 1 hours,
            signature
        );

        assertEq(profileNFT.getProfileTier(user1), 3);
    }

    function test_TierCalculation_Platinum() public {
        vm.prank(user1);
        profileNFT.register();

        // Update to level 7 = Platinum (tier 4)
        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 700,
            level: 7,
            runCount: 15,
            achievementCount: 3,
            totalDistanceMeters: 15000,
            longestStreakDays: 7,
            lastUpdated: uint64(block.timestamp)
        });

        bytes memory signature = _signStatsUpdate(
            user1,
            stats,
            0,
            block.timestamp + 1 hours
        );
        profileNFT.updateStats(
            user1,
            stats,
            block.timestamp + 1 hours,
            signature
        );

        assertEq(profileNFT.getProfileTier(user1), 4);
    }

    function test_TierCalculation_Diamond() public {
        vm.prank(user1);
        profileNFT.register();

        // Update to level 9 = Diamond (tier 5)
        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 900,
            level: 9,
            runCount: 20,
            achievementCount: 5,
            totalDistanceMeters: 20000,
            longestStreakDays: 10,
            lastUpdated: uint64(block.timestamp)
        });

        bytes memory signature = _signStatsUpdate(
            user1,
            stats,
            0,
            block.timestamp + 1 hours
        );
        profileNFT.updateStats(
            user1,
            stats,
            block.timestamp + 1 hours,
            signature
        );

        assertEq(profileNFT.getProfileTier(user1), 5);
    }

    // ========== Tier Upgrade Event Tests ==========

    function test_TierUpgradeEvent() public {
        vm.prank(user1);
        profileNFT.register();

        // Upgrade from Bronze (1) to Silver (2)
        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 300,
            level: 3,
            runCount: 5,
            achievementCount: 1,
            totalDistanceMeters: 5000,
            longestStreakDays: 3,
            lastUpdated: uint64(block.timestamp)
        });

        bytes memory signature = _signStatsUpdate(
            user1,
            stats,
            0,
            block.timestamp + 1 hours
        );

        vm.expectEmit(true, false, false, true);
        emit ProfileTierUpgraded(user1, 1, 2);
        profileNFT.updateStats(
            user1,
            stats,
            block.timestamp + 1 hours,
            signature
        );
    }

    // ========== Stats Update Tests ==========

    function test_UpdateStats() public {
        vm.prank(user1);
        profileNFT.register();

        IRuneraProfile.ProfileStats memory newStats = IRuneraProfile
            .ProfileStats({
                xp: 1000,
                level: 5,
                runCount: 10,
                achievementCount: 3,
                totalDistanceMeters: 10000,
                longestStreakDays: 5,
                lastUpdated: uint64(block.timestamp)
            });

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = profileNFT.getNonce(user1);
        bytes memory signature = _signStatsUpdate(
            user1,
            newStats,
            nonce,
            deadline
        );

        profileNFT.updateStats(user1, newStats, deadline, signature);

        IRuneraProfile.ProfileData memory profile = profileNFT.getProfile(
            user1
        );
        assertEq(profile.xp, 1000);
        assertEq(profile.level, 5);
        assertEq(profile.runCount, 10);
        assertEq(profile.achievementCount, 3);
    }

    function test_UpdateStatsExpiredSignature() public {
        vm.prank(user1);
        profileNFT.register();

        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 100,
            level: 2,
            runCount: 1,
            achievementCount: 0,
            totalDistanceMeters: 1000,
            longestStreakDays: 1,
            lastUpdated: uint64(block.timestamp)
        });

        uint256 deadline = block.timestamp - 1; // Expired
        bytes memory signature = _signStatsUpdate(user1, stats, 0, deadline);

        vm.expectRevert(RuneraProfileDynamicNFT.SignatureExpired.selector);
        profileNFT.updateStats(user1, stats, deadline, signature);
    }

    function test_UpdateStatsInvalidSigner() public {
        vm.prank(user1);
        profileNFT.register();

        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 100,
            level: 2,
            runCount: 1,
            achievementCount: 0,
            totalDistanceMeters: 1000,
            longestStreakDays: 1,
            lastUpdated: uint64(block.timestamp)
        });

        uint256 deadline = block.timestamp + 1 hours;
        uint256 wrongPrivateKey = 0x9999;
        bytes memory signature = _signStatsUpdateWithKey(
            user1,
            stats,
            0,
            deadline,
            wrongPrivateKey
        );

        vm.expectRevert(RuneraProfileDynamicNFT.InvalidSigner.selector);
        profileNFT.updateStats(user1, stats, deadline, signature);
    }

    function test_NonceIncrements() public {
        vm.prank(user1);
        profileNFT.register();

        assertEq(profileNFT.getNonce(user1), 0);

        IRuneraProfile.ProfileStats memory stats = IRuneraProfile.ProfileStats({
            xp: 100,
            level: 2,
            runCount: 1,
            achievementCount: 0,
            totalDistanceMeters: 1000,
            longestStreakDays: 1,
            lastUpdated: uint64(block.timestamp)
        });

        bytes memory signature = _signStatsUpdate(
            user1,
            stats,
            0,
            block.timestamp + 1 hours
        );
        profileNFT.updateStats(
            user1,
            stats,
            block.timestamp + 1 hours,
            signature
        );

        assertEq(profileNFT.getNonce(user1), 1);
    }

    // ========== URI Tests ==========

    function test_URIGeneration() public {
        vm.prank(user1);
        profileNFT.register();

        uint256 tokenId = profileNFT.getTokenId(user1);
        string memory uri = profileNFT.uri(tokenId);

        // Should contain base URI and user address
        assertTrue(bytes(uri).length > 0);
    }

    function test_TokenIdDeterministic() public {
        // Token ID should be deterministic based on address
        uint256 tokenId1 = profileNFT.getTokenId(user1);
        uint256 tokenId2 = profileNFT.getTokenId(user1);

        assertEq(tokenId1, tokenId2);
        assertEq(tokenId1, uint256(uint160(user1)));
    }

    // ========== Soulbound Tests ==========

    function test_CannotTransfer() public {
        vm.prank(user1);
        profileNFT.register();

        uint256 tokenId = profileNFT.getTokenId(user1);

        vm.prank(user1);
        vm.expectRevert(RuneraProfileDynamicNFT.SoulboundToken.selector);
        profileNFT.safeTransferFrom(user1, user2, tokenId, 1, "");
    }

    function test_CannotSetApprovalForAll() public {
        vm.prank(user1);
        vm.expectRevert(RuneraProfileDynamicNFT.SoulboundToken.selector);
        profileNFT.setApprovalForAll(user2, true);
    }

    // ========== Helper Functions ==========

    function _signRegister(
        address user,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(REGISTER_TYPEHASH, user, nonce, deadline)
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                profileNFT.domainSeparator(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signStatsUpdate(
        address user,
        IRuneraProfile.ProfileStats memory stats,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        return
            _signStatsUpdateWithKey(
                user,
                stats,
                nonce,
                deadline,
                backendSignerPrivateKey
            );
    }

    function _signStatsUpdateWithKey(
        address user,
        IRuneraProfile.ProfileStats memory stats,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                STATS_UPDATE_TYPEHASH,
                user,
                stats.xp,
                stats.level,
                stats.runCount,
                stats.achievementCount,
                stats.totalDistanceMeters,
                stats.longestStreakDays,
                stats.lastUpdated,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                profileNFT.domainSeparator(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
