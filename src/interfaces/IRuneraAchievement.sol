// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRuneraAchievement
 * @notice Interface for Runera Achievement Registry (On-Chain Data)
 */
interface IRuneraAchievement {
    /// @notice Achievement data struct (stored on-chain)
    struct AchievementData {
        bytes32 eventId; // ID of the event
        uint8 tier; // Achievement tier (1-5)
        uint64 unlockedAt; // Timestamp when unlocked
        bytes32 metadataHash; // Hash of metadata (gas efficient)
        bool exists; // Flag to check if claimed
    }

    /// @notice Emitted when an achievement is claimed
    event AchievementClaimed(
        address indexed user,
        bytes32 indexed eventId,
        uint8 tier
    );

    /// @notice Claim an achievement
    /// @param to The recipient address
    /// @param eventId The event ID this achievement is for
    /// @param tier The achievement tier (1-5)
    /// @param metadataHash Hash of the achievement metadata
    /// @param deadline Signature expiration timestamp
    /// @param signature Backend signer's signature
    function claim(
        address to,
        bytes32 eventId,
        uint8 tier,
        bytes32 metadataHash,
        uint256 deadline,
        bytes calldata signature
    ) external;

    /// @notice Check if a user has an achievement for a specific event
    /// @param user The address of the user
    /// @param eventId The event ID to check
    /// @return True if the user has the achievement
    function hasAchievement(
        address user,
        bytes32 eventId
    ) external view returns (bool);

    /// @notice Get achievement data for a user and event
    /// @param user The address of the user
    /// @param eventId The event ID
    /// @return The achievement data
    function getAchievement(
        address user,
        bytes32 eventId
    ) external view returns (AchievementData memory);

    /// @notice Get all achievement event IDs for a user
    /// @param user The address of the user
    /// @return Array of event IDs the user has achievements for
    function getUserAchievements(
        address user
    ) external view returns (bytes32[] memory);

    /// @notice Get the count of achievements for a user
    /// @param user The address of the user
    /// @return The number of achievements
    function getUserAchievementCount(
        address user
    ) external view returns (uint256);
}
