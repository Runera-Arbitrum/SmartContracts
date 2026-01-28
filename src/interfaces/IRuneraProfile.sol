// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRuneraProfile
 * @notice Interface for Runera Profile Registry (On-Chain Data)
 */
interface IRuneraProfile {
    /// @notice Profile data struct (stored on-chain)
    /// @dev Optimized for running app: includes distance and streak
    struct ProfileData {
        uint96 xp; // Enough for 79 Octillion XP
        uint16 level; // Up to 65,535 levels
        uint32 runCount; // Total verified runs (renamed from tasksCompleted)
        uint32 achievementCount; // Up to 4.2B achievements
        uint64 totalDistanceMeters; // Lifetime distance in meters
        uint32 longestStreakDays; // Longest consecutive running days
        uint64 lastUpdated; // Timestamp (valid until year 584942)
        bool exists; // Flag to check if registered
    }

    /// @notice Stats struct for updates (without exists flag)
    struct ProfileStats {
        uint96 xp;
        uint16 level;
        uint32 runCount;
        uint32 achievementCount;
        uint64 totalDistanceMeters;
        uint32 longestStreakDays;
        uint64 lastUpdated;
    }

    /// @notice Emitted when a profile is registered
    event ProfileRegistered(address indexed user);

    /// @notice Emitted when profile stats are updated
    event StatsUpdated(address indexed user, ProfileStats stats);

    /// @notice Register a new profile for the caller
    function register() external;

    /// @notice Update stats for a user's profile (requires valid backend signature)
    /// @param user The address of the user
    /// @param stats The new stats to set
    /// @param deadline Signature expiration timestamp
    /// @param signature Backend signer's signature
    function updateStats(
        address user,
        ProfileStats calldata stats,
        uint256 deadline,
        bytes calldata signature
    ) external;

    /// @notice Get the profile data for a user
    /// @param user The address of the user
    /// @return The user's profile data
    function getProfile(
        address user
    ) external view returns (ProfileData memory);

    /// @notice Check if a user has a profile
    /// @param user The address to check
    /// @return True if the user has a profile
    function hasProfile(address user) external view returns (bool);
}
