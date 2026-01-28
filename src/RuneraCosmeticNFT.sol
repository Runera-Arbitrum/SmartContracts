// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IRuneraCosmeticNFT} from "./interfaces/IRuneraCosmeticNFT.sol";
import {RuneraAccessControl} from "./access/RuneraAccessControl.sol";

/**
 * @title RuneraCosmeticNFT
 * @notice ERC-1155 Cosmetic NFT for Runera - Layer 3 (Economy)
 * @dev Transferable customization items with category system
 *
 * Key Features:
 * - Item catalog with categories (shoes, outfits, accessories, frames)
 * - Rarity system (Common → Mythic)
 * - Equip/unequip mechanics (one per category)
 * - Supply management
 * - Tier-gated items (require minimum profile tier)
 * - TRANSFERABLE (unlike Profile/Achievement NFTs)
 *
 * Gas Optimizations:
 * - Packed structs (CosmeticItem = 5 slots)
 * - Uint8 for category/rarity enums
 * - Cached role for access control
 * - Bitmap for equipped items (future optimization)
 */
contract RuneraCosmeticNFT is ERC1155, IRuneraCosmeticNFT {
    /// @notice Reference to access control contract
    RuneraAccessControl public immutable accessControl;

    /// @notice Cached admin role for gas optimization
    bytes32 private immutable _cachedAdminRole;

    /// @notice Base metadata URI
    string private _baseMetadataURI;

    /// @notice Item catalog: itemId => item data
    mapping(uint256 => CosmeticItem) private _items;

    /// @notice Equipped items: user => category => itemId
    mapping(address => mapping(Category => uint256)) private _equipped;

    /// @notice Custom errors
    error ItemAlreadyExists();
    error ItemNotFound();
    error ItemNotOwned();
    error MaxSupplyReached();
    error TierRequirementNotMet();
    error Unauthorized();
    error InvalidCategory();
    error ItemNotEquipped();

    /**
     * @notice Initialize cosmetic NFT contract
     * @param _accessControl Address of access control contract
     * @param baseURI Base URI for metadata
     */
    constructor(address _accessControl, string memory baseURI) ERC1155("") {
        accessControl = RuneraAccessControl(_accessControl);
        _cachedAdminRole = accessControl.DEFAULT_ADMIN_ROLE();
        _baseMetadataURI = baseURI;
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     * @dev Only admin can create items
     */
    function createItem(
        uint256 itemId,
        string calldata name,
        Category category,
        Rarity rarity,
        bytes32 ipfsHash,
        uint32 maxSupply,
        uint8 minTierRequired
    ) external {
        if (!accessControl.hasRole(_cachedAdminRole, msg.sender)) {
            revert Unauthorized();
        }

        if (_items[itemId].exists) {
            revert ItemAlreadyExists();
        }

        // Validate category (0-3 for 4 categories)
        if (uint8(category) > 3) {
            revert InvalidCategory();
        }

        _items[itemId] = CosmeticItem({
            name: name,
            category: category,
            rarity: rarity,
            ipfsHash: ipfsHash,
            maxSupply: maxSupply,
            currentSupply: 0,
            minTierRequired: minTierRequired,
            exists: true
        });

        emit ItemCreated(itemId, name, category, rarity);
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     * @dev Only admin can mint items
     */
    function mintItem(address to, uint256 itemId, uint256 amount) external {
        if (!accessControl.hasRole(_cachedAdminRole, msg.sender)) {
            revert Unauthorized();
        }

        CosmeticItem storage item = _items[itemId];
        if (!item.exists) {
            revert ItemNotFound();
        }

        // Check supply limit (0 = unlimited)
        if (item.maxSupply > 0) {
            uint256 newSupply = item.currentSupply + uint32(amount);
            if (newSupply > item.maxSupply) {
                revert MaxSupplyReached();
            }
            item.currentSupply = uint32(newSupply);
        }

        _mint(to, itemId, amount, "");
        emit ItemMinted(to, itemId, amount);
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     * @dev User must own the item to equip
     */
    function equipItem(Category category, uint256 itemId) external {
        // Verify ownership
        if (balanceOf(msg.sender, itemId) == 0) {
            revert ItemNotOwned();
        }

        CosmeticItem memory item = _items[itemId];
        if (!item.exists) {
            revert ItemNotFound();
        }

        // Verify category matches
        if (item.category != category) {
            revert InvalidCategory();
        }

        // Note: Tier requirement check would require Profile contract integration
        // For now, we skip tier check to keep contract independent
        // Backend should validate tier before allowing equip

        _equipped[msg.sender][category] = itemId;
        emit ItemEquipped(msg.sender, category, itemId);
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     */
    function unequipItem(Category category) external {
        uint256 equippedId = _equipped[msg.sender][category];
        if (equippedId == 0) {
            revert ItemNotEquipped();
        }

        delete _equipped[msg.sender][category];
        emit ItemUnequipped(msg.sender, category);
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     */
    function getEquipped(
        address user,
        Category category
    ) external view returns (uint256 itemId) {
        return _equipped[user][category];
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     */
    function getAllEquipped(
        address user
    ) external view returns (uint256[4] memory equipped) {
        equipped[0] = _equipped[user][Category.SHOES];
        equipped[1] = _equipped[user][Category.OUTFIT];
        equipped[2] = _equipped[user][Category.ACCESSORY];
        equipped[3] = _equipped[user][Category.FRAME];
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     */
    function getItem(
        uint256 itemId
    ) external view returns (CosmeticItem memory item) {
        if (!_items[itemId].exists) {
            revert ItemNotFound();
        }
        return _items[itemId];
    }

    /**
     * @inheritdoc IRuneraCosmeticNFT
     */
    function itemExists(uint256 itemId) external view returns (bool exists) {
        return _items[itemId].exists;
    }

    /**
     * @notice Get metadata URI for token
     * @param itemId Token ID
     * @return URI string
     */
    function uri(uint256 itemId) public view override returns (string memory) {
        if (!_items[itemId].exists) {
            return "";
        }

        // Format: {baseURI}{itemId}/metadata
        return
            string(
                abi.encodePacked(
                    _baseMetadataURI,
                    _toHexString(itemId),
                    "/metadata"
                )
            );
    }

    /**
     * @notice Update base metadata URI (admin only)
     * @param newBaseURI New base URI
     */
    function setBaseURI(string memory newBaseURI) external {
        if (!accessControl.hasRole(_cachedAdminRole, msg.sender)) {
            revert Unauthorized();
        }
        _baseMetadataURI = newBaseURI;
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
