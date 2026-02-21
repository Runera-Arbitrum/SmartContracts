// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRuneraEventRegistry
 * @notice Interface for Runera Event Registry
 */
interface IRuneraEventRegistry {
    /// @notice Event configuration struct
    /// @dev Optimized packing: uint64 for timestamps (valid until year 584942), uint32 for participants (up to 4.2B)
    struct EventConfig {
        bytes32 eventId;
        string name;
        uint64 startTime;
        uint64 endTime;
        uint32 maxParticipants;
        uint32 currentParticipants;
        bool active;
    }

    /// @notice Reward configuration for an event
    /// @dev Stored separately to keep EventConfig gas-efficient
    struct EventReward {
        uint8 achievementTier; // Achievement tier to award (0 = no achievement, valid: 1-5)
        uint256[] cosmeticItemIds; // Cosmetic item IDs to award (empty = no cosmetic)
        uint96 xpBonus; // Bonus XP hint for backend (0 = no bonus)
        bool hasReward; // Whether this event has any reward configured
    }

    /// @notice Emitted when a new event is created
    event EventCreated(
        bytes32 indexed eventId,
        string name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants
    );

    /// @notice Emitted when an event is updated
    event EventUpdated(bytes32 indexed eventId, EventConfig config);

    /// @notice Emitted when event participant count changes
    event ParticipantAdded(bytes32 indexed eventId, uint256 newCount);

    /// @notice Emitted when reward config is set or updated for an event
    event EventRewardConfigured(
        bytes32 indexed eventId,
        uint8 achievementTier,
        uint256[] cosmeticItemIds,
        uint96 xpBonus
    );

    /// @notice Create a new event
    /// @param eventId Unique identifier for the event
    /// @param name Human-readable event name
    /// @param startTime Unix timestamp when event starts
    /// @param endTime Unix timestamp when event ends
    /// @param maxParticipants Maximum number of participants (0 for unlimited)
    /// @param reward Reward configuration for event completers (set hasReward=false for no reward)
    function createEvent(
        bytes32 eventId,
        string calldata name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants,
        EventReward calldata reward
    ) external;

    /// @notice Update an existing event
    /// @param eventId The event to update
    /// @param name New name
    /// @param startTime New start time
    /// @param endTime New end time
    /// @param maxParticipants New max participants
    /// @param active Whether the event is active
    function updateEvent(
        bytes32 eventId,
        string calldata name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants,
        bool active
    ) external;

    /// @notice Set or update reward configuration for an existing event
    /// @param eventId The event to configure reward for
    /// @param reward The reward configuration
    function setEventReward(
        bytes32 eventId,
        EventReward calldata reward
    ) external;

    /// @notice Get event configuration
    /// @param eventId The event to query
    /// @return config The event configuration
    function getEvent(
        bytes32 eventId
    ) external view returns (EventConfig memory config);

    /// @notice Get reward configuration for an event
    /// @param eventId The event to query
    /// @return reward The reward configuration
    function getEventReward(
        bytes32 eventId
    ) external view returns (EventReward memory reward);

    /// @notice Check if an event is currently active
    /// @param eventId The event to check
    /// @return isActive True if event is active and within time window
    function isEventActive(
        bytes32 eventId
    ) external view returns (bool isActive);

    /// @notice Check if an event exists
    /// @param eventId The event to check
    /// @return exists True if event exists
    function eventExists(bytes32 eventId) external view returns (bool exists);

    /// @notice Increment participant count for an event
    /// @param eventId The event to update
    function incrementParticipants(bytes32 eventId) external;
}
