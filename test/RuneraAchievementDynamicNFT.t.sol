// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";
import {RuneraEventRegistry} from "../src/RuneraEventRegistry.sol";
import {
    RuneraAchievementDynamicNFT
} from "../src/RuneraAchievementDynamicNFT.sol";
import {IRuneraAchievement} from "../src/interfaces/IRuneraAchievement.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RuneraAchievementDynamicNFTTest is Test {
    RuneraAccessControl public accessControl;
    RuneraEventRegistry public eventRegistry;
    RuneraAchievementDynamicNFT public achievementNFT;

    address public admin = address(1);
    uint256 public backendSignerPrivateKey = 0x1234;
    address public backendSigner;
    address public eventManager = address(3);

    address public user1 = address(10);
    address public user2 = address(20);

    bytes32 public constant EVENT_ID_1 = keccak256("GENESIS_EVENT");
    bytes32 public constant METADATA_HASH = keccak256("ipfs://QmTest");

    string constant BASE_URI = "https://api.runera.xyz/achievement/";

    // EIP-712 TypeHash
    bytes32 constant ACHIEVEMENT_CLAIM_TYPEHASH =
        keccak256(
            "ClaimAchievement(address to,bytes32 eventId,uint8 tier,bytes32 metadataHash,uint256 nonce,uint256 deadline)"
        );

    // Events
    event AchievementClaimed(
        address indexed user,
        bytes32 indexed eventId,
        uint8 tier
    );
    event AchievementNFTMinted(
        address indexed user,
        uint256 tokenId,
        bytes32 indexed eventId,
        uint8 tier
    );

    function setUp() public {
        vm.warp(1 days); // Avoid underflow in timestamp math
        backendSigner = vm.addr(backendSignerPrivateKey);

        vm.startPrank(admin);
        accessControl = new RuneraAccessControl();
        eventRegistry = new RuneraEventRegistry(address(accessControl));
        achievementNFT = new RuneraAchievementDynamicNFT(
            address(accessControl),
            BASE_URI
        );

        // Grant roles
        accessControl.grantRole(
            accessControl.BACKEND_SIGNER_ROLE(),
            backendSigner
        );
        accessControl.grantRole(
            accessControl.EVENT_MANAGER_ROLE(),
            eventManager
        );
        vm.stopPrank();

        // Create test event
        vm.prank(eventManager);
        eventRegistry.createEvent(
            EVENT_ID_1,
            "Genesis Event",
            block.timestamp - 1 hours,
            block.timestamp + 1 hours,
            100
        );
    }

    // ========== Claim Achievement Tests ==========

    function test_ClaimAchievement() public {
        uint8 tier = 3;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = achievementNFT.getNonce(user1);

        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            nonce,
            deadline
        );

        vm.prank(user1);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );

        assertTrue(achievementNFT.hasAchievement(user1, EVENT_ID_1));
    }

    function test_ClaimAchievementEmitsEvents() public {
        uint8 tier = 5;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            0,
            deadline
        );

        uint256 expectedTokenId = achievementNFT.getAchievementTokenId(
            user1,
            EVENT_ID_1
        );

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit AchievementClaimed(user1, EVENT_ID_1, tier);
        vm.expectEmit(true, true, true, true);
        emit AchievementNFTMinted(user1, expectedTokenId, EVENT_ID_1, tier);

        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );
    }

    function test_ClaimMintsNFT() public {
        uint8 tier = 2;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            0,
            deadline
        );

        vm.prank(user1);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );

        uint256 tokenId = achievementNFT.getAchievementTokenId(
            user1,
            EVENT_ID_1
        );
        assertEq(achievementNFT.balanceOf(user1, tokenId), 1);
    }

    // ========== Token ID Tests ==========

    function test_AchievementTokenIdDeterministic() public {
        uint256 tokenId1 = achievementNFT.getAchievementTokenId(
            user1,
            EVENT_ID_1
        );
        uint256 tokenId2 = achievementNFT.getAchievementTokenId(
            user1,
            EVENT_ID_1
        );

        assertEq(tokenId1, tokenId2);
        assertEq(
            tokenId1,
            uint256(keccak256(abi.encodePacked(user1, EVENT_ID_1)))
        );
    }

    function test_DifferentUsersDifferentTokenIds() public {
        uint256 tokenId1 = achievementNFT.getAchievementTokenId(
            user1,
            EVENT_ID_1
        );
        uint256 tokenId2 = achievementNFT.getAchievementTokenId(
            user2,
            EVENT_ID_1
        );

        assertTrue(tokenId1 != tokenId2);
    }

    // ========== Tier Validation Tests ==========

    function test_TierBasedMinting() public {
        for (uint8 tier = 1; tier <= 5; tier++) {
            address user = address(uint160(100 + tier));
            bytes32 eventId = keccak256(abi.encodePacked("EVENT_", tier));

            uint256 deadline = block.timestamp + 1 hours;
            bytes memory signature = _signClaim(
                user,
                eventId,
                tier,
                METADATA_HASH,
                0,
                deadline
            );

            vm.prank(user);
            achievementNFT.claim(
                user,
                eventId,
                tier,
                METADATA_HASH,
                deadline,
                signature
            );

            IRuneraAchievement.AchievementData memory data = achievementNFT
                .getAchievement(user, eventId);
            assertEq(data.tier, tier);
        }
    }

    function test_InvalidTierReverts() public {
        uint8 invalidTier = 6; // Max is 5
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            invalidTier,
            METADATA_HASH,
            0,
            deadline
        );

        vm.prank(user1);
        vm.expectRevert(RuneraAchievementDynamicNFT.InvalidTier.selector);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            invalidTier,
            METADATA_HASH,
            deadline,
            signature
        );
    }

    // ========== Duplicate Prevention Tests ==========

    function test_DuplicateClaimReverts() public {
        uint8 tier = 3;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            0,
            deadline
        );

        vm.startPrank(user1);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );

        // Try to claim again
        bytes memory signature2 = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            1,
            deadline
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                RuneraAchievementDynamicNFT.AlreadyHasAchievement.selector,
                user1,
                EVENT_ID_1
            )
        );
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature2
        );
        vm.stopPrank();
    }

    // ========== Soulbound Tests ==========

    function test_SoulboundTransferReverts() public {
        uint8 tier = 3;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            0,
            deadline
        );

        vm.prank(user1);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );

        uint256 tokenId = achievementNFT.getAchievementTokenId(
            user1,
            EVENT_ID_1
        );

        vm.prank(user1);
        vm.expectRevert(RuneraAchievementDynamicNFT.SoulboundToken.selector);
        achievementNFT.safeTransferFrom(user1, user2, tokenId, 1, "");
    }

    function test_CannotSetApprovalForAll() public {
        vm.prank(user1);
        vm.expectRevert(RuneraAchievementDynamicNFT.SoulboundToken.selector);
        achievementNFT.setApprovalForAll(user2, true);
    }

    // ========== URI Tests ==========

    function test_DynamicURIGeneration() public {
        uint8 tier = 4;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            0,
            deadline
        );

        vm.prank(user1);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );

        uint256 tokenId = achievementNFT.getAchievementTokenId(
            user1,
            EVENT_ID_1
        );
        string memory uri = achievementNFT.uri(tokenId);

        assertTrue(bytes(uri).length > 0);
    }

    // ========== Signature Tests ==========

    function test_SignatureExpiredReverts() public {
        uint8 tier = 3;
        uint256 deadline = block.timestamp - 1; // Expired
        bytes memory signature = _signClaim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            0,
            deadline
        );

        vm.prank(user1);
        vm.expectRevert(RuneraAchievementDynamicNFT.SignatureExpired.selector);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );
    }

    function test_InvalidSignerReverts() public {
        uint8 tier = 3;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 wrongKey = 0x9999;
        bytes memory signature = _signClaimWithKey(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            0,
            deadline,
            wrongKey
        );

        vm.prank(user1);
        vm.expectRevert(RuneraAchievementDynamicNFT.InvalidSigner.selector);
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );
    }

    function test_NonceIncrements() public {
        assertEq(achievementNFT.getNonce(user1), 0);

        uint8 tier = 3;
        bytes32 eventId2 = keccak256("EVENT_2");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = _signClaim(
            user1,
            eventId2,
            tier,
            METADATA_HASH,
            0,
            deadline
        );

        vm.prank(user1);
        achievementNFT.claim(
            user1,
            eventId2,
            tier,
            METADATA_HASH,
            deadline,
            signature
        );

        assertEq(achievementNFT.getNonce(user1), 1);
    }

    // ========== User Enumeration Tests ==========

    function test_UserAchievementEnumeration() public {
        bytes32 event2 = keccak256("EVENT_2");
        bytes32 event3 = keccak256("EVENT_3");

        uint256 deadline = block.timestamp + 1 hours;

        // Claim 3 achievements
        vm.startPrank(user1);

        bytes memory sig1 = _signClaim(
            user1,
            EVENT_ID_1,
            1,
            METADATA_HASH,
            0,
            deadline
        );
        achievementNFT.claim(
            user1,
            EVENT_ID_1,
            1,
            METADATA_HASH,
            deadline,
            sig1
        );

        bytes memory sig2 = _signClaim(
            user1,
            event2,
            2,
            METADATA_HASH,
            1,
            deadline
        );
        achievementNFT.claim(user1, event2, 2, METADATA_HASH, deadline, sig2);

        bytes memory sig3 = _signClaim(
            user1,
            event3,
            3,
            METADATA_HASH,
            2,
            deadline
        );
        achievementNFT.claim(user1, event3, 3, METADATA_HASH, deadline, sig3);

        vm.stopPrank();

        bytes32[] memory achievements = achievementNFT.getUserAchievements(
            user1
        );
        assertEq(achievements.length, 3);
        assertEq(achievements[0], EVENT_ID_1);
        assertEq(achievements[1], event2);
        assertEq(achievements[2], event3);
    }

    // ========== Helper Functions ==========

    function _signClaim(
        address to,
        bytes32 eventId,
        uint8 tier,
        bytes32 metadataHash,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        return
            _signClaimWithKey(
                to,
                eventId,
                tier,
                metadataHash,
                nonce,
                deadline,
                backendSignerPrivateKey
            );
    }

    function _signClaimWithKey(
        address to,
        bytes32 eventId,
        uint8 tier,
        bytes32 metadataHash,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                ACHIEVEMENT_CLAIM_TYPEHASH,
                to,
                eventId,
                tier,
                metadataHash,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                achievementNFT.domainSeparator(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
