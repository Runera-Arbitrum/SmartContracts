// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRuneraCosmeticNFT
 * @notice Interface for Runera Cosmetic NFT contract
 * @dev Layer 3 of Runera Identity Protocol - Transferable customization items
 */
interface IRuneraCosmeticNFT {
    /// @notice Item categories for cosmetics
    enum Category {
        SHOES,
        OUTFIT,
        ACCESSORY,
        FRAME
    }

    /// @notice Rarity levels for items
    enum Rarity {
        COMMON,
        RARE,
        EPIC,
        LEGENDARY,
        MYTHIC
    }

    /// @notice Cosmetic item metadata
    struct CosmeticItem {
        string name;
        Category category;
        Rarity rarity;
        bytes32 ipfsHash; // IPFS hash for image
        uint32 maxSupply; // 0 = unlimited
        uint32 currentSupply;
        uint8 minTierRequired; // Minimum profile tier to equip
        bool exists;
    }

    /// @notice Item created event
    event ItemCreated(
        uint256 indexed itemId,
        string name,
        Category category,
        Rarity rarity
    );

    /// @notice Item minted event
    event ItemMinted(
        address indexed to,
        uint256 indexed itemId,
        uint256 amount
    );

    /// @notice Item equipped event
    event ItemEquipped(
        address indexed user,
        Category indexed category,
        uint256 itemId
    );

    /// @notice Item unequipped event
    event ItemUnequipped(address indexed user, Category indexed category);

    /**
     * @notice Create a new cosmetic item type (admin only)
     * @param itemId Unique item identifier
     * @param name Item name
     * @param category Item category
     * @param rarity Item rarity
     * @param ipfsHash IPFS hash for image
     * @param maxSupply Maximum supply (0 for unlimited)
     * @param minTierRequired Minimum profile tier to equip
     */
    function createItem(
        uint256 itemId,
        string calldata name,
        Category category,
        Rarity rarity,
        bytes32 ipfsHash,
        uint32 maxSupply,
        uint8 minTierRequired
    ) external;

    /**
     * @notice Mint cosmetic item to user
     * @param to Recipient address
     * @param itemId Item to mint
     * @param amount Quantity to mint
     */
    function mintItem(address to, uint256 itemId, uint256 amount) external;

    /**
     * @notice Equip an item (requires ownership)
     * @param category Category slot to equip
     * @param itemId Item to equip
     */
    function equipItem(Category category, uint256 itemId) external;

    /**
     * @notice Unequip an item from slot
     * @param category Category slot to unequip
     */
    function unequipItem(Category category) external;

    /**
     * @notice Get equipped item for user in category
     * @param user User address
     * @param category Item category
     * @return itemId Equipped item ID (0 if nothing equipped)
     */
    function getEquipped(
        address user,
        Category category
    ) external view returns (uint256 itemId);

    /**
     * @notice Get all equipped items for user
     * @param user User address
     * @return equipped Array of 4 item IDs (one per category)
     */
    function getAllEquipped(
        address user
    ) external view returns (uint256[4] memory equipped);

    /**
     * @notice Get item metadata
     * @param itemId Item identifier
     * @return item Item metadata
     */
    function getItem(
        uint256 itemId
    ) external view returns (CosmeticItem memory item);

    /**
     * @notice Check if item exists
     * @param itemId Item identifier
     * @return exists True if item exists
     */
    function itemExists(uint256 itemId) external view returns (bool exists);
}
