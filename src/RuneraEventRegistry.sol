// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRuneraEventRegistry} from "./interfaces/IRuneraEventRegistry.sol";
import {RuneraAccessControl} from "./access/RuneraAccessControl.sol";

/**
 * @title RuneraEventRegistry
 * @notice Registry for managing Runera events with time-based activation
 * @dev Requires EVENT_MANAGER_ROLE for create/update operations
 */
contract RuneraEventRegistry is IRuneraEventRegistry {
    /// @notice Reference to access control contract
    RuneraAccessControl public immutable accessControl;

    /// @notice Cached role for gas optimization
    bytes32 private immutable _cachedEventManagerRole;

    /// @notice Mapping of event ID to event configuration
    mapping(bytes32 => EventConfig) private _events;

    /// @notice Array of all event IDs for enumeration
    bytes32[] private _eventIds;

    /// @notice Custom errors
    error EventAlreadyExists(bytes32 eventId);
    error EventDoesNotExist(bytes32 eventId);
    error InvalidTimeWindow();
    error NotEventManager();
    error EventFull();

    /// @notice Modifier to restrict access to event managers
    modifier onlyEventManager() {
        _onlyEventManager();
        _;
    }

    /// @notice Internal function for event manager check (reduces code size)
    function _onlyEventManager() internal view {
        if (!accessControl.hasRole(_cachedEventManagerRole, msg.sender)) {
            revert NotEventManager();
        }
    }

    /**
     * @notice Initialize with access control contract
     * @param _accessControl Address of the access control contract
     */
    constructor(address _accessControl) {
        accessControl = RuneraAccessControl(_accessControl);
        _cachedEventManagerRole = accessControl.EVENT_MANAGER_ROLE();
    }

    /**
     * @inheritdoc IRuneraEventRegistry
     */
    function createEvent(
        bytes32 eventId,
        string calldata name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants
    ) external onlyEventManager {
        if (_events[eventId].eventId != bytes32(0)) {
            revert EventAlreadyExists(eventId);
        }
        if (startTime >= endTime) {
            revert InvalidTimeWindow();
        }

        _events[eventId] = EventConfig({
            eventId: eventId,
            name: name,
            startTime: uint64(startTime),
            endTime: uint64(endTime),
            maxParticipants: uint32(maxParticipants),
            currentParticipants: 0,
            active: true
        });

        _eventIds.push(eventId);

        emit EventCreated(eventId, name, startTime, endTime, maxParticipants);
    }

    /**
     * @inheritdoc IRuneraEventRegistry
     */
    function updateEvent(
        bytes32 eventId,
        string calldata name,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants,
        bool active
    ) external onlyEventManager {
        if (_events[eventId].eventId == bytes32(0)) {
            revert EventDoesNotExist(eventId);
        }
        if (startTime >= endTime) {
            revert InvalidTimeWindow();
        }

        EventConfig storage config = _events[eventId];
        config.name = name;
        config.startTime = uint64(startTime);
        config.endTime = uint64(endTime);
        config.maxParticipants = uint32(maxParticipants);
        config.active = active;

        emit EventUpdated(eventId, config);
    }

    /**
     * @inheritdoc IRuneraEventRegistry
     */
    function getEvent(
        bytes32 eventId
    ) external view returns (EventConfig memory config) {
        if (_events[eventId].eventId == bytes32(0)) {
            revert EventDoesNotExist(eventId);
        }
        return _events[eventId];
    }

    /**
     * @inheritdoc IRuneraEventRegistry
     */
    function isEventActive(
        bytes32 eventId
    ) external view returns (bool isActive) {
        EventConfig storage config = _events[eventId];
        if (config.eventId == bytes32(0)) {
            return false;
        }

        bool withinTimeWindow = block.timestamp >= config.startTime &&
            block.timestamp <= config.endTime;
        bool hasCapacity = config.maxParticipants == 0 ||
            config.currentParticipants < config.maxParticipants;

        return config.active && withinTimeWindow && hasCapacity;
    }

    /**
     * @inheritdoc IRuneraEventRegistry
     */
    function eventExists(bytes32 eventId) external view returns (bool exists) {
        return _events[eventId].eventId != bytes32(0);
    }

    /**
     * @inheritdoc IRuneraEventRegistry
     */
    function incrementParticipants(bytes32 eventId) external onlyEventManager {
        EventConfig storage config = _events[eventId];
        if (config.eventId == bytes32(0)) {
            revert EventDoesNotExist(eventId);
        }
        if (
            config.maxParticipants > 0 &&
            config.currentParticipants >= config.maxParticipants
        ) {
            revert EventFull();
        }

        unchecked {
            ++config.currentParticipants;
        }
        emit ParticipantAdded(eventId, config.currentParticipants);
    }

    /**
     * @notice Get total number of events
     * @return count The total event count
     */
    function getEventCount() external view returns (uint256 count) {
        return _eventIds.length;
    }

    /**
     * @notice Get event ID by index
     * @param index The index to query
     * @return eventId The event ID at given index
     */
    function getEventIdByIndex(
        uint256 index
    ) external view returns (bytes32 eventId) {
        return _eventIds[index];
    }
}
