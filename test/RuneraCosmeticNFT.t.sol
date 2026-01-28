// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";
import {RuneraCosmeticNFT} from "../src/RuneraCosmeticNFT.sol";
import {IRuneraCosmeticNFT} from "../src/interfaces/IRuneraCosmeticNFT.sol";

contract RuneraCosmeticNFTTest is Test {
    // using IRuneraCosmeticNFT for *; // Removed: cannot use interface as library

    RuneraAccessControl public accessControl;
    RuneraCosmeticNFT public cosmeticNFT;

    address public admin = address(1);
    address public user1 = address(10);
    address public user2 = address(20);

    string constant BASE_URI = "https://api.runera.xyz/cosmetic/";
    bytes32 constant IPFS_HASH = keccak256("ipfs://QmTestHash");

    // Sample item IDs
    uint256 constant ITEM_SHOES_1 = 1;
    uint256 constant ITEM_OUTFIT_1 = 100;
    uint256 constant ITEM_ACCESSORY_1 = 200;
    uint256 constant ITEM_FRAME_1 = 300;

    // Events
    event ItemCreated(
        uint256 indexed itemId,
        string name,
        IRuneraCosmeticNFT.Category category,
        IRuneraCosmeticNFT.Rarity rarity
    );
    event ItemMinted(
        address indexed to,
        uint256 indexed itemId,
        uint256 amount
    );
    event ItemEquipped(
        address indexed user,
        IRuneraCosmeticNFT.Category indexed category,
        uint256 itemId
    );
    event ItemUnequipped(
        address indexed user,
        IRuneraCosmeticNFT.Category indexed category
    );

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new RuneraAccessControl();
        cosmeticNFT = new RuneraCosmeticNFT(address(accessControl), BASE_URI);
        vm.stopPrank();
    }

    // ========== Item Creation Tests ==========

    function test_CreateItem() public {
        vm.prank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100, // max supply
            1 // min tier
        );

        assertTrue(cosmeticNFT.itemExists(ITEM_SHOES_1));
    }

    function test_CreateItemEmitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ItemCreated(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE
        );

        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
    }

    function test_CreateDuplicateItemReverts() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );

        vm.expectRevert(RuneraCosmeticNFT.ItemAlreadyExists.selector);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Duplicate",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.COMMON,
            IPFS_HASH,
            50,
            1
        );
        vm.stopPrank();
    }

    function test_CreateItemNonAdminReverts() public {
        vm.prank(user1);
        vm.expectRevert(RuneraCosmeticNFT.Unauthorized.selector);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
    }

    function test_GetItem() public {
        vm.prank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.EPIC,
            IPFS_HASH,
            100,
            2
        );

        IRuneraCosmeticNFT.CosmeticItem memory item = cosmeticNFT.getItem(
            ITEM_SHOES_1
        );

        assertEq(item.name, "Speed Boots");
        assertEq(
            uint8(item.category),
            uint8(IRuneraCosmeticNFT.Category.SHOES)
        );
        assertEq(uint8(item.rarity), uint8(IRuneraCosmeticNFT.Rarity.EPIC));
        assertEq(item.maxSupply, 100);
        assertEq(item.minTierRequired, 2);
        assertTrue(item.exists);
    }

    // ========== Minting Tests ==========

    function test_MintItem() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
        vm.stopPrank();

        assertEq(cosmeticNFT.balanceOf(user1, ITEM_SHOES_1), 1);
    }

    function test_MintItemEmitsEvent() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );

        vm.expectEmit(true, true, false, true);
        emit ItemMinted(user1, ITEM_SHOES_1, 5);
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 5);
        vm.stopPrank();
    }

    function test_MintExceedsSupplyReverts() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            10,
            1
        );

        vm.expectRevert(RuneraCosmeticNFT.MaxSupplyReached.selector);
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 11);
        vm.stopPrank();
    }

    function test_MintUnlimitedSupply() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.COMMON,
            IPFS_HASH,
            0,
            1
        ); // 0 = unlimited

        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1000);
        vm.stopPrank();

        assertEq(cosmeticNFT.balanceOf(user1, ITEM_SHOES_1), 1000);
    }

    function test_MintNonExistentItemReverts() public {
        vm.prank(admin);
        vm.expectRevert(RuneraCosmeticNFT.ItemNotFound.selector);
        cosmeticNFT.mintItem(user1, 999, 1);
    }

    function test_MintNonAdminReverts() public {
        vm.prank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );

        vm.prank(user1);
        vm.expectRevert(RuneraCosmeticNFT.Unauthorized.selector);
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
    }

    // ========== Equip/Unequip Tests ==========

    function test_EquipItem() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
        vm.stopPrank();

        vm.prank(user1);
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.SHOES, ITEM_SHOES_1);

        assertEq(
            cosmeticNFT.getEquipped(user1, IRuneraCosmeticNFT.Category.SHOES),
            ITEM_SHOES_1
        );
    }

    function test_EquipItemEmitsEvent() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit ItemEquipped(
            user1,
            IRuneraCosmeticNFT.Category.SHOES,
            ITEM_SHOES_1
        );
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.SHOES, ITEM_SHOES_1);
    }

    function test_EquipWithoutOwnershipReverts() public {
        vm.prank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );

        vm.prank(user1);
        vm.expectRevert(RuneraCosmeticNFT.ItemNotOwned.selector);
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.SHOES, ITEM_SHOES_1);
    }

    function test_EquipWrongCategoryReverts() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(RuneraCosmeticNFT.InvalidCategory.selector);
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.OUTFIT, ITEM_SHOES_1); // Wrong category
    }

    function test_UnequipItem() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
        vm.stopPrank();

        vm.startPrank(user1);
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.SHOES, ITEM_SHOES_1);
        cosmeticNFT.unequipItem(IRuneraCosmeticNFT.Category.SHOES);
        vm.stopPrank();

        assertEq(
            cosmeticNFT.getEquipped(user1, IRuneraCosmeticNFT.Category.SHOES),
            0
        );
    }

    function test_UnequipItemEmitsEvent() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
        vm.stopPrank();

        vm.startPrank(user1);
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.SHOES, ITEM_SHOES_1);

        vm.expectEmit(true, true, false, false);
        emit ItemUnequipped(user1, IRuneraCosmeticNFT.Category.SHOES);
        cosmeticNFT.unequipItem(IRuneraCosmeticNFT.Category.SHOES);
        vm.stopPrank();
    }

    function test_UnequipNothingReverts() public {
        vm.prank(user1);
        vm.expectRevert(RuneraCosmeticNFT.ItemNotEquipped.selector);
        cosmeticNFT.unequipItem(IRuneraCosmeticNFT.Category.SHOES);
    }

    function test_GetAllEquipped() public {
        // Create items for all categories
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.createItem(
            ITEM_OUTFIT_1,
            "Pro Suit",
            IRuneraCosmeticNFT.Category.OUTFIT,
            IRuneraCosmeticNFT.Rarity.EPIC,
            IPFS_HASH,
            50,
            1
        );
        cosmeticNFT.createItem(
            ITEM_ACCESSORY_1,
            "Headband",
            IRuneraCosmeticNFT.Category.ACCESSORY,
            IRuneraCosmeticNFT.Rarity.COMMON,
            IPFS_HASH,
            200,
            1
        );
        cosmeticNFT.createItem(
            ITEM_FRAME_1,
            "Gold Frame",
            IRuneraCosmeticNFT.Category.FRAME,
            IRuneraCosmeticNFT.Rarity.LEGENDARY,
            IPFS_HASH,
            10,
            3
        );

        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1);
        cosmeticNFT.mintItem(user1, ITEM_OUTFIT_1, 1);
        cosmeticNFT.mintItem(user1, ITEM_ACCESSORY_1, 1);
        cosmeticNFT.mintItem(user1, ITEM_FRAME_1, 1);
        vm.stopPrank();

        // Equip all
        vm.startPrank(user1);
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.SHOES, ITEM_SHOES_1);
        cosmeticNFT.equipItem(
            IRuneraCosmeticNFT.Category.OUTFIT,
            ITEM_OUTFIT_1
        );
        cosmeticNFT.equipItem(
            IRuneraCosmeticNFT.Category.ACCESSORY,
            ITEM_ACCESSORY_1
        );
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.FRAME, ITEM_FRAME_1);
        vm.stopPrank();

        uint256[4] memory equipped = cosmeticNFT.getAllEquipped(user1);
        assertEq(equipped[0], ITEM_SHOES_1);
        assertEq(equipped[1], ITEM_OUTFIT_1);
        assertEq(equipped[2], ITEM_ACCESSORY_1);
        assertEq(equipped[3], ITEM_FRAME_1);
    }

    // ========== Transfer Tests (Cosmetics ARE Transferable!) ==========

    function test_TransferItem() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 5);
        vm.stopPrank();

        vm.prank(user1);
        cosmeticNFT.safeTransferFrom(user1, user2, ITEM_SHOES_1, 2, "");

        assertEq(cosmeticNFT.balanceOf(user1, ITEM_SHOES_1), 3);
        assertEq(cosmeticNFT.balanceOf(user2, ITEM_SHOES_1), 2);
    }

    function test_TransferAfterEquipStillEquipped() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 2);
        vm.stopPrank();

        vm.startPrank(user1);
        cosmeticNFT.equipItem(IRuneraCosmeticNFT.Category.SHOES, ITEM_SHOES_1);

        // Transfer one copy (still have one)
        cosmeticNFT.safeTransferFrom(user1, user2, ITEM_SHOES_1, 1, "");
        vm.stopPrank();

        // Should still be equipped (we kept one copy)
        assertEq(
            cosmeticNFT.getEquipped(user1, IRuneraCosmeticNFT.Category.SHOES),
            ITEM_SHOES_1
        );
    }

    // ========== URI Tests ==========

    function test_URIGeneration() public {
        vm.prank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );

        string memory uri = cosmeticNFT.uri(ITEM_SHOES_1);
        assertTrue(bytes(uri).length > 0);
    }

    function test_SetBaseURI() public {
        string memory newURI = "https://new.api.runera.xyz/cosmetic/";

        vm.prank(admin);
        cosmeticNFT.setBaseURI(newURI);

        vm.prank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );

        string memory uri = cosmeticNFT.uri(ITEM_SHOES_1);
        assertTrue(bytes(uri).length > 0);
    }

    // ========== Supply Management Tests ==========

    function test_MaxSupplyEnforcement() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            10,
            1
        );

        // Mint 10 (max)
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 10);

        // Try to mint one more
        vm.expectRevert(RuneraCosmeticNFT.MaxSupplyReached.selector);
        cosmeticNFT.mintItem(user2, ITEM_SHOES_1, 1);
        vm.stopPrank();
    }

    function test_CurrentSupplyTracking() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Speed Boots",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            100,
            1
        );

        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 5);
        cosmeticNFT.mintItem(user2, ITEM_SHOES_1, 3);
        vm.stopPrank();

        IRuneraCosmeticNFT.CosmeticItem memory item = cosmeticNFT.getItem(
            ITEM_SHOES_1
        );
        assertEq(item.currentSupply, 8);
    }

    function test_UnlimitedSupplyItems() public {
        vm.startPrank(admin);
        cosmeticNFT.createItem(
            ITEM_SHOES_1,
            "Basic Shoes",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.COMMON,
            IPFS_HASH,
            0,
            1
        ); // 0 = unlimited

        // Mint tons
        cosmeticNFT.mintItem(user1, ITEM_SHOES_1, 1000);
        cosmeticNFT.mintItem(user2, ITEM_SHOES_1, 500);
        vm.stopPrank();

        assertEq(cosmeticNFT.balanceOf(user1, ITEM_SHOES_1), 1000);
        assertEq(cosmeticNFT.balanceOf(user2, ITEM_SHOES_1), 500);
    }
}
