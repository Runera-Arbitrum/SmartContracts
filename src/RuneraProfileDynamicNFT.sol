// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IRuneraProfile} from "./interfaces/IRuneraProfile.sol";
import {RuneraAccessControl} from "./access/RuneraAccessControl.sol";

/**
 * @title RuneraProfileDynamicNFT
 * @notice ERC-1155 Profile NFT with dynamic tier-based metadata and on-chain data storage
 * @dev Combines NFT visibility with gas-efficient on-chain registry pattern
 *
 * Key Features:
 * - One profile NFT per wallet (soulbound, non-transferable)
 * - Deterministic token ID: uint256(uint160(address))
 * - Dynamic metadata URI based on profile tier
 * - On-chain data storage (gas optimized)
 * - EIP-712 signature-based stats updates
 * - Tier system: Bronze → Silver → Gold → Platinum → Diamond
 */
contract RuneraProfileDynamicNFT is ERC1155, EIP712, IRuneraProfile {
    using ECDSA for bytes32;

    /// @notice Reference to access control contract
    RuneraAccessControl public immutable accessControl;

    /// @notice Cached role for gas optimization
    bytes32 private immutable _cachedBackendSignerRole;

    /// @notice Base URI for metadata API
    string private _baseMetadataURI;

    /// @notice Mapping from user address to their profile data
    mapping(address => ProfileData) private _profiles;

    /// @notice Mapping to track used nonces for signature replay protection
    mapping(address => uint256) public nonces;

    /// @notice EIP-712 type hash for stats update
    bytes32 public constant STATS_UPDATE_TYPEHASH =
        keccak256(
            "StatsUpdate(address user,uint96 xp,uint16 level,uint32 runCount,uint32 achievementCount,uint64 totalDistanceMeters,uint32 longestStreakDays,uint64 lastUpdated,uint256 nonce,uint256 deadline)"
        );

    /// @notice EIP-712 type hash for gasless registration
    bytes32 public constant REGISTER_TYPEHASH =
        keccak256("Register(address user,uint256 nonce,uint256 deadline)");

    /// @notice Mapping to track registration nonces (separate from stats nonces)
    mapping(address => uint256) public registerNonces;

    /// @notice Tier thresholds (DEMO MODE - minimal for testing)
    uint16 public constant TIER_SILVER = 3; // Level 3+ = Silver
    uint16 public constant TIER_GOLD = 5; // Level 5+ = Gold
    uint16 public constant TIER_PLATINUM = 7; // Level 7+ = Platinum
    uint16 public constant TIER_DIAMOND = 9; // Level 9+ = Diamond

    /// @notice Tier values
    uint8 public constant TIER_BRONZE_VALUE = 1;
    uint8 public constant TIER_SILVER_VALUE = 2;
    uint8 public constant TIER_GOLD_VALUE = 3;
    uint8 public constant TIER_PLATINUM_VALUE = 4;
    uint8 public constant TIER_DIAMOND_VALUE = 5;

    /// @notice Custom errors
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidSignature();
    error SignatureExpired();
    error InvalidSigner();
    error SoulboundToken();

    /// @notice NFT-specific events
    event ProfileNFTMinted(address indexed user, uint256 tokenId, uint8 tier);
    event ProfileTierUpgraded(
        address indexed user,
        uint8 oldTier,
        uint8 newTier
    );

    /**
     * @notice Initialize the profile dynamic NFT contract
     * @param _accessControl Address of the access control contract
     * @param baseURI Base URI for metadata (e.g., "https://api.runera.xyz/profile/")
     */
    constructor(
        address _accessControl,
        string memory baseURI
    ) ERC1155("") EIP712("RuneraProfileDynamicNFT", "1") {
        accessControl = RuneraAccessControl(_accessControl);
        _cachedBackendSignerRole = accessControl.BACKEND_SIGNER_ROLE();
        _baseMetadataURI = baseURI;
    }

    /**
     * @inheritdoc IRuneraProfile
     * @dev Mints ERC-1155 NFT with tokenId = uint256(uint160(address))
     */
    function register() external {
        if (_profiles[msg.sender].exists) {
            revert AlreadyRegistered();
        }

        _profiles[msg.sender] = ProfileData({
            xp: 0,
            level: 1,
            runCount: 0,
            achievementCount: 0,
            totalDistanceMeters: 0,
            longestStreakDays: 0,
            lastUpdated: uint64(block.timestamp),
            exists: true
        });

        uint256 tokenId = getTokenId(msg.sender);
        uint8 tier = getProfileTier(msg.sender);

        // Mint NFT with balance = 1
        _mint(msg.sender, tokenId, 1, "");

        emit ProfileRegistered(msg.sender);
        emit ProfileNFTMinted(msg.sender, tokenId, tier);
    }

    /**
     * @notice Register a profile on behalf of a user (gasless)
     * @dev Anyone can call this to relay, but user must sign
     * @param user The address to register
     * @param deadline Signature expiry timestamp
     * @param signature EIP-712 signature from the user
     */
    function registerFor(
        address user,
        uint256 deadline,
        bytes calldata signature
    ) external {
        // Check deadline
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        // Check not already registered
        if (_profiles[user].exists) {
            revert AlreadyRegistered();
        }

        // Get and increment nonce
        uint256 currentNonce = registerNonces[user];
        registerNonces[user] = currentNonce + 1;

        // Verify EIP-712 signature from user
        bytes32 structHash = keccak256(
            abi.encode(REGISTER_TYPEHASH, user, currentNonce, deadline)
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);

        // User must sign their own registration
        if (signer != user) {
            revert InvalidSignature();
        }

        // Create profile
        _profiles[user] = ProfileData({
            xp: 0,
            level: 1,
            runCount: 0,
            achievementCount: 0,
            totalDistanceMeters: 0,
            longestStreakDays: 0,
            lastUpdated: uint64(block.timestamp),
            exists: true
        });

        uint256 tokenId = getTokenId(user);
        uint8 tier = getProfileTier(user);

        // Mint NFT
        _mint(user, tokenId, 1, "");

        emit ProfileRegistered(user);
        emit ProfileNFTMinted(user, tokenId, tier);
    }

    /**
     * @notice Get registration nonce for a user
     * @param user The user address
     * @return The current registration nonce
     */
    function getRegisterNonce(address user) external view returns (uint256) {
        return registerNonces[user];
    }

    /**
     * @inheritdoc IRuneraProfile
     * @dev Updates profile stats and checks for tier upgrades
     */
    function updateStats(
        address user,
        ProfileStats calldata stats,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) {
            revert SignatureExpired();
        }

        if (!_profiles[user].exists) {
            revert NotRegistered();
        }

        // Get current nonce and increment
        uint256 currentNonce = nonces[user];
        nonces[user] = currentNonce + 1;

        // Verify signature from backend signer
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
                currentNonce,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);

        if (!accessControl.hasRole(_cachedBackendSignerRole, signer)) {
            revert InvalidSigner();
        }

        // Check for tier upgrade
        uint8 oldTier = _calculateTier(_profiles[user].level);
        uint8 newTier = _calculateTier(stats.level);

        // Update profile data in storage
        ProfileData storage profile = _profiles[user];
        profile.xp = stats.xp;
        profile.level = stats.level;
        profile.runCount = stats.runCount;
        profile.achievementCount = stats.achievementCount;
        profile.totalDistanceMeters = stats.totalDistanceMeters;
        profile.longestStreakDays = stats.longestStreakDays;
        profile.lastUpdated = stats.lastUpdated;

        emit StatsUpdated(user, stats);

        // Emit tier upgrade event if tier changed
        if (newTier > oldTier) {
            emit ProfileTierUpgraded(user, oldTier, newTier);
        }
    }

    /**
     * @inheritdoc IRuneraProfile
     */
    function getProfile(
        address user
    ) external view returns (ProfileData memory) {
        if (!_profiles[user].exists) {
            revert NotRegistered();
        }
        return _profiles[user];
    }

    /**
     * @inheritdoc IRuneraProfile
     */
    function hasProfile(address user) external view returns (bool) {
        return _profiles[user].exists;
    }

    /**
     * @notice Get the current tier for a user's profile
     * @param user The address of the user
     * @return tier The tier value (1=Bronze, 2=Silver, 3=Gold, 4=Platinum, 5=Diamond)
     */
    function getProfileTier(address user) public view returns (uint8 tier) {
        if (!_profiles[user].exists) {
            return 0;
        }
        return _calculateTier(_profiles[user].level);
    }

    /**
     * @notice Get deterministic token ID for a user
     * @param user The address of the user
     * @return tokenId The token ID (uint256 representation of address)
     */
    function getTokenId(address user) public pure returns (uint256 tokenId) {
        return uint256(uint160(user));
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
        address user = address(uint160(tokenId));
        if (!_profiles[user].exists) {
            return "";
        }

        // Format: {baseURI}{address}/metadata
        return
            string(
                abi.encodePacked(
                    _baseMetadataURI,
                    _toHexString(user),
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
     * @dev Calculate tier based on level (internal helper)
     * @param level The user's level
     * @return tier The calculated tier (1-5)
     */
    function _calculateTier(uint16 level) internal pure returns (uint8 tier) {
        if (level >= TIER_DIAMOND) return TIER_DIAMOND_VALUE;
        if (level >= TIER_PLATINUM) return TIER_PLATINUM_VALUE;
        if (level >= TIER_GOLD) return TIER_GOLD_VALUE;
        if (level >= TIER_SILVER) return TIER_SILVER_VALUE;
        return TIER_BRONZE_VALUE; // Level 1-2
    }

    /**
     * @dev Override to make tokens soulbound (non-transferable)
     * @dev Allows minting but blocks transfers between non-zero addresses
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
     * @dev Convert address to hex string (for URI generation)
     * @param addr The address to convert
     * @return The hex string representation (0x...)
     */
    function _toHexString(address addr) internal pure returns (string memory) {
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            uint8 value = uint8(uint160(addr) >> (8 * (19 - i)));
            uint8 hi = value >> 4;
            uint8 lo = value & 0x0f;

            buffer[2 + i * 2] = _toHexChar(hi);
            buffer[3 + i * 2] = _toHexChar(lo);
        }

        return string(buffer);
    }

    /**
     * @dev Convert a nibble to hex character
     * @param value The nibble (0-15)
     * @return The hex character
     */
    function _toHexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(uint8(bytes1("0")) + value);
        } else {
            return bytes1(uint8(bytes1("a")) + value - 10);
        }
    }
}
