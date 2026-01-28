// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IRuneraAchievement} from "./interfaces/IRuneraAchievement.sol";
import {RuneraAccessControl} from "./access/RuneraAccessControl.sol";

/**
 * @title RuneraAchievementDynamicNFT
 * @notice ERC-1155 Achievement NFT with event-based minting and tier system
 * @dev Combines NFT ecosystem visibility with gas-efficient on-chain storage
 *
 * Key Features:
 * - One achievement NFT per user per event (soulbound)
 * - Deterministic token ID: keccak256(abi.encodePacked(address, eventId))
 * - Dynamic metadata URI based on tier (1-5)
 * - On-chain achievement data storage
 * - EIP-712 signature-based claiming
 * - User achievement enumeration
 */
contract RuneraAchievementDynamicNFT is ERC1155, EIP712, IRuneraAchievement {
    using ECDSA for bytes32;

    /// @notice Reference to access control contract
    RuneraAccessControl public immutable accessControl;

    /// @notice Cached role for gas optimization
    bytes32 private immutable _cachedBackendSignerRole;

    /// @notice Base URI for metadata API
    string private _baseMetadataURI;

    /// @notice Mapping from token ID to achievement data
    mapping(uint256 => AchievementData) private _achievements;

    /// @notice Reverse mapping: user => eventId => tokenId (for duplicate prevention)
    mapping(address => mapping(bytes32 => uint256)) private _userEventTokens;

    /// @notice Mapping from user to list of event IDs (for enumeration)
    mapping(address => bytes32[]) private _userAchievementList;

    /// @notice Mapping to track used nonces for signature replay protection
    mapping(address => uint256) public nonces;

    /// @notice EIP-712 type hash for achievement claiming
    bytes32 public constant CLAIM_TYPEHASH =
        keccak256(
            "ClaimAchievement(address to,bytes32 eventId,uint8 tier,bytes32 metadataHash,uint256 nonce,uint256 deadline)"
        );

    /// @notice Custom errors
    error AlreadyHasAchievement(address user, bytes32 eventId);
    error NoAchievement();
    error SignatureExpired();
    error InvalidSigner();
    error InvalidTier();
    error SoulboundToken();

    /// @notice NFT-specific events
    event AchievementNFTMinted(
        address indexed user,
        uint256 tokenId,
        bytes32 indexed eventId,
        uint8 tier
    );

    /**
     * @notice Initialize the achievement dynamic NFT contract
     * @param _accessControl Address of the access control contract
     * @param baseURI Base URI for metadata (e.g., "https://api.runera.xyz/achievement/")
     */
    constructor(
        address _accessControl,
        string memory baseURI
    ) ERC1155("") EIP712("RuneraAchievementDynamicNFT", "1") {
        accessControl = RuneraAccessControl(_accessControl);
        _cachedBackendSignerRole = accessControl.BACKEND_SIGNER_ROLE();
        _baseMetadataURI = baseURI;
    }

    /**
     * @inheritdoc IRuneraAchievement
     * @dev Mints ERC-1155 NFT with deterministic tokenId
     */
    function claim(
        address to,
        bytes32 eventId,
        uint8 tier,
        bytes32 metadataHash,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        // Check for duplicate achievement
        if (_userEventTokens[to][eventId] != 0) {
            revert AlreadyHasAchievement(to, eventId);
        }

        // Validate tier (1-5 tier system)
        if (tier == 0 || tier > 5) {
            revert InvalidTier();
        }

        // Get current nonce and increment
        uint256 currentNonce = nonces[to];
        nonces[to] = currentNonce + 1;

        // Verify signature from backend signer
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                to,
                eventId,
                tier,
                metadataHash,
                currentNonce,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);

        if (!accessControl.hasRole(_cachedBackendSignerRole, signer)) {
            revert InvalidSigner();
        }

        // Generate deterministic token ID
        uint256 tokenId = getAchievementTokenId(to, eventId);

        // Store achievement data
        _achievements[tokenId] = AchievementData({
            eventId: eventId,
            tier: tier,
            unlockedAt: uint64(block.timestamp),
            metadataHash: metadataHash,
            exists: true
        });

        // Store reverse mapping
        _userEventTokens[to][eventId] = tokenId;

        // Add to user's achievement list for enumeration
        _userAchievementList[to].push(eventId);

        // Mint NFT with balance = 1
        _mint(to, tokenId, 1, "");

        emit AchievementClaimed(to, eventId, tier);
        emit AchievementNFTMinted(to, tokenId, eventId, tier);
    }

    /**
     * @inheritdoc IRuneraAchievement
     */
    function hasAchievement(
        address user,
        bytes32 eventId
    ) external view returns (bool) {
        return _userEventTokens[user][eventId] != 0;
    }

    /**
     * @inheritdoc IRuneraAchievement
     */
    function getAchievement(
        address user,
        bytes32 eventId
    ) external view returns (AchievementData memory) {
        uint256 tokenId = _userEventTokens[user][eventId];
        if (tokenId == 0) {
            revert NoAchievement();
        }
        return _achievements[tokenId];
    }

    /**
     * @inheritdoc IRuneraAchievement
     */
    function getUserAchievements(
        address user
    ) external view returns (bytes32[] memory) {
        return _userAchievementList[user];
    }

    /**
     * @inheritdoc IRuneraAchievement
     */
    function getUserAchievementCount(
        address user
    ) external view returns (uint256) {
        return _userAchievementList[user].length;
    }

    /**
     * @notice Get achievement data by token ID
     * @param tokenId The token ID
     * @return The achievement data
     */
    function getAchievementByTokenId(
        uint256 tokenId
    ) external view returns (AchievementData memory) {
        if (!_achievements[tokenId].exists) {
            revert NoAchievement();
        }
        return _achievements[tokenId];
    }

    /**
     * @notice Get deterministic token ID for user + event combination
     * @param user The user address
     * @param eventId The event ID
     * @return tokenId The deterministic token ID
     */
    function getAchievementTokenId(
        address user,
        bytes32 eventId
    ) public pure returns (uint256 tokenId) {
        return uint256(keccak256(abi.encodePacked(user, eventId)));
    }

    /**
     * @notice Get the current nonce for a user (for signature generation)
     * @param user The user address
     * @return The current nonce
     */
    function getNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    /**
     * @notice Get the domain separator for EIP-712
     * @return The domain separator
     */
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @notice Get dynamic metadata URI for a token
     * @param tokenId The token ID
     * @return The metadata URI pointing to API endpoint
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        if (!_achievements[tokenId].exists) {
            return "";
        }

        // Format: {baseURI}{tokenId}/metadata
        return
            string(
                abi.encodePacked(
                    _baseMetadataURI,
                    _toHexString(tokenId),
                    "/metadata"
                )
            );
    }

    /**
     * @notice Update base metadata URI (admin only)
     * @param newBaseURI The new base URI
     */
    function setBaseURI(string memory newBaseURI) external {
        if (
            !accessControl.hasRole(
                accessControl.DEFAULT_ADMIN_ROLE(),
                msg.sender
            )
        ) {
            revert InvalidSigner();
        }
        _baseMetadataURI = newBaseURI;
    }

    /**
     * @dev Override to make tokens soulbound (non-transferable)
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        // Allow minting (from == 0) and burning (to == 0)
        // Block transfers between users
        if (from != address(0) && to != address(0)) {
            revert SoulboundToken();
        }

        super._update(from, to, ids, values);
    }

    /**
     * @dev Override setApprovalForAll to disable approvals (soulbound)
     */
    function setApprovalForAll(address, bool) public pure override {
        revert SoulboundToken();
    }

    /**
     * @dev Convert uint256 to hex string
     */
    function _toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x0";
        }

        uint256 temp = value;
        uint256 length = 0;

        while (temp != 0) {
            length++;
            temp >>= 4;
        }

        bytes memory buffer = new bytes(2 + length);
        buffer[0] = "0";
        buffer[1] = "x";

        for (uint256 i = length; i > 0; i--) {
            uint8 nibble = uint8(value & 0xf);
            buffer[1 + i] = _toHexChar(nibble);
            value >>= 4;
        }

        return string(buffer);
    }

    /**
     * @dev Convert a nibble to hex character
     */
    function _toHexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(uint8(bytes1("0")) + value);
        } else {
            return bytes1(uint8(bytes1("a")) + value - 10);
        }
    }
}
