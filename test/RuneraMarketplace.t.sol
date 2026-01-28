// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuneraAccessControl} from "../src/access/RuneraAccessControl.sol";
import {RuneraCosmeticNFT} from "../src/RuneraCosmeticNFT.sol";
import {RuneraMarketplace} from "../src/RuneraMarketplace.sol";
import {IRuneraCosmeticNFT} from "../src/interfaces/IRuneraCosmeticNFT.sol";
import {IRuneraMarketplace} from "../src/interfaces/IRuneraMarketplace.sol";

contract RuneraMarketplaceTest is Test {
    RuneraAccessControl public accessControl;
    RuneraCosmeticNFT public cosmeticNFT;
    RuneraMarketplace public marketplace;

    address public admin = address(1);
    address public seller = address(10);
    address public buyer = address(20);

    string constant BASE_URI = "https://api.runera.xyz/cosmetic/";
    bytes32 constant IPFS_HASH = keccak256("ipfs://QmTestHash");

    uint256 constant ITEM_ID = 1;
    uint256 constant PRICE_PER_UNIT = 0.1 ether;

    // Events
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed itemId,
        uint256 amount,
        uint256 pricePerUnit
    );
    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event ItemSold(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer,
        uint256 itemId,
        uint256 amount,
        uint256 totalPrice,
        uint256 platformFee
    );

    function setUp() public {
        vm.startPrank(admin);
        accessControl = new RuneraAccessControl();
        cosmeticNFT = new RuneraCosmeticNFT(address(accessControl), BASE_URI);
        marketplace = new RuneraMarketplace(
            address(accessControl),
            address(cosmeticNFT)
        );

        // Create and mint test item
        cosmeticNFT.createItem(
            ITEM_ID,
            "Test Item",
            IRuneraCosmeticNFT.Category.SHOES,
            IRuneraCosmeticNFT.Rarity.RARE,
            IPFS_HASH,
            1000,
            1
        );
        cosmeticNFT.mintItem(seller, ITEM_ID, 10);
        vm.stopPrank();

        // Give seller and buyer some ETH
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
    }

    // ========== Listing Creation Tests ==========

    function test_CreateListing() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );
        vm.stopPrank();

        assertEq(listingId, 1);

        IRuneraMarketplace.Listing memory listing = marketplace.getListing(
            listingId
        );
        assertEq(listing.seller, seller);
        assertEq(listing.itemId, ITEM_ID);
        assertEq(listing.amount, 5);
        assertEq(listing.pricePerUnit, PRICE_PER_UNIT);
        assertEq(
            uint8(listing.status),
            uint8(IRuneraMarketplace.ListingStatus.ACTIVE)
        );
    }

    function test_CreateListingTransfersNFT() public {
        uint256 sellerBalanceBefore = cosmeticNFT.balanceOf(seller, ITEM_ID);

        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);
        marketplace.createListing(ITEM_ID, 5, PRICE_PER_UNIT);
        vm.stopPrank();

        assertEq(
            cosmeticNFT.balanceOf(seller, ITEM_ID),
            sellerBalanceBefore - 5
        );
        assertEq(cosmeticNFT.balanceOf(address(marketplace), ITEM_ID), 5);
    }

    function test_CreateListingEmitsEvent() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.expectEmit(true, true, true, true);
        emit ListingCreated(1, seller, ITEM_ID, 5, PRICE_PER_UNIT);
        marketplace.createListing(ITEM_ID, 5, PRICE_PER_UNIT);
        vm.stopPrank();
    }

    function test_CreateListingInsufficientBalanceReverts() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.expectRevert();
        marketplace.createListing(ITEM_ID, 100, PRICE_PER_UNIT); // Only has 10
        vm.stopPrank();
    }

    function test_CreateListingZeroAmountReverts() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.expectRevert(RuneraMarketplace.InvalidAmount.selector);
        marketplace.createListing(ITEM_ID, 0, PRICE_PER_UNIT);
        vm.stopPrank();
    }

    function test_CreateListingZeroPriceReverts() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.expectRevert(RuneraMarketplace.InvalidPrice.selector);
        marketplace.createListing(ITEM_ID, 5, 0);
        vm.stopPrank();
    }

    // ========== Cancel Listing Tests ==========

    function test_CancelListing() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        marketplace.cancelListing(listingId);
        vm.stopPrank();

        IRuneraMarketplace.Listing memory listing = marketplace.getListing(
            listingId
        );
        assertEq(
            uint8(listing.status),
            uint8(IRuneraMarketplace.ListingStatus.CANCELLED)
        );
    }

    function test_CancelListingReturnsNFT() public {
        uint256 sellerBalanceBefore = cosmeticNFT.balanceOf(seller, ITEM_ID);

        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        marketplace.cancelListing(listingId);
        vm.stopPrank();

        assertEq(cosmeticNFT.balanceOf(seller, ITEM_ID), sellerBalanceBefore);
        assertEq(cosmeticNFT.balanceOf(address(marketplace), ITEM_ID), 0);
    }

    function test_CancelListingEmitsEvent() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        vm.expectEmit(true, true, false, false);
        emit ListingCancelled(listingId, seller);
        marketplace.cancelListing(listingId);
        vm.stopPrank();
    }

    function test_OnlySellerCanCancel() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        vm.prank(buyer);
        vm.expectRevert(RuneraMarketplace.NotSeller.selector);
        marketplace.cancelListing(listingId);
    }

    function test_CancelInactiveListingReverts() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        vm.startPrank(seller);
        marketplace.cancelListing(listingId);

        vm.expectRevert(RuneraMarketplace.ListingNotActive.selector);
        marketplace.cancelListing(listingId);
        vm.stopPrank();
    }

    // ========== Buy Item Tests ==========

    function test_BuyItem() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        uint256 totalPrice = PRICE_PER_UNIT * 5;

        vm.prank(buyer);
        marketplace.buyItem{value: totalPrice}(listingId, 5);

        assertEq(cosmeticNFT.balanceOf(buyer, ITEM_ID), 5);
    }

    function test_BuyPartialAmount() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        uint256 totalPrice = PRICE_PER_UNIT * 2;

        vm.prank(buyer);
        marketplace.buyItem{value: totalPrice}(listingId, 2);

        assertEq(cosmeticNFT.balanceOf(buyer, ITEM_ID), 2);

        IRuneraMarketplace.Listing memory listing = marketplace.getListing(
            listingId
        );
        assertEq(listing.amount, 3); // 3 remaining
        assertEq(
            uint8(listing.status),
            uint8(IRuneraMarketplace.ListingStatus.ACTIVE)
        );
    }

    function test_BuyInsufficientPaymentReverts() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        vm.prank(buyer);
        vm.expectRevert(RuneraMarketplace.InsufficientPayment.selector);
        marketplace.buyItem{value: 0.01 ether}(listingId, 5); // Too little
    }

    function test_BuyInactiveListingReverts() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        vm.prank(seller);
        marketplace.cancelListing(listingId);

        uint256 totalPrice = PRICE_PER_UNIT * 5;

        vm.prank(buyer);
        vm.expectRevert(RuneraMarketplace.ListingNotActive.selector);
        marketplace.buyItem{value: totalPrice}(listingId, 5);
    }

    function test_BuyAllMarksAsSold() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        uint256 totalPrice = PRICE_PER_UNIT * 5;

        vm.prank(buyer);
        marketplace.buyItem{value: totalPrice}(listingId, 5);

        IRuneraMarketplace.Listing memory listing = marketplace.getListing(
            listingId
        );
        assertEq(
            uint8(listing.status),
            uint8(IRuneraMarketplace.ListingStatus.SOLD)
        );
        assertEq(listing.amount, 0);
    }

    // ========== Platform Fee Tests ==========

    function test_PlatformFeeCalculation() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(
            ITEM_ID,
            5,
            PRICE_PER_UNIT
        );

        uint256 totalPrice = PRICE_PER_UNIT * 5;
        uint256 expectedFee = (totalPrice * 500) / 10000; // 5% of 0.5 ETH = 0.025 ETH

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buyItem{value: totalPrice}(listingId, 5);

        uint256 sellerBalanceAfter = seller.balance;
        uint256 sellerReceived = sellerBalanceAfter - sellerBalanceBefore;

        assertEq(sellerReceived, totalPrice - expectedFee);
        assertEq(marketplace.getAccumulatedFees(), expectedFee);
    }

    function test_SellerReceivesCorrectAmount() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(ITEM_ID, 1, 1 ether);

        uint256 sellerBalanceBefore = seller.balance;

        vm.prank(buyer);
        marketplace.buyItem{value: 1 ether}(listingId, 1);

        uint256 sellerBalanceAfter = seller.balance;
        uint256 sellerReceived = sellerBalanceAfter - sellerBalanceBefore;

        // 1 ETH - 5% fee = 0.95 ETH
        assertEq(sellerReceived, 0.95 ether);
    }

    function test_ExcessPaymentRefunded() public {
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(ITEM_ID, 1, 0.1 ether);

        uint256 buyerBalanceBefore = buyer.balance;

        vm.prank(buyer);
        marketplace.buyItem{value: 1 ether}(listingId, 1); // Pay 1 ETH for 0.1 ETH item

        uint256 buyerBalanceAfter = buyer.balance;
        uint256 buyerSpent = buyerBalanceBefore - buyerBalanceAfter;

        assertEq(buyerSpent, 0.1 ether); // Only spent 0.1 ETH
    }

    function test_SetPlatformFee() public {
        vm.prank(admin);
        marketplace.setPlatformFee(1000); // 10%

        assertEq(marketplace.getPlatformFee(), 1000);
    }

    function test_SetPlatformFeeNonAdminReverts() public {
        vm.prank(buyer);
        vm.expectRevert(RuneraMarketplace.Unauthorized.selector);
        marketplace.setPlatformFee(1000);
    }

    function test_SetPlatformFeeExceedsMaxReverts() public {
        vm.prank(admin);
        vm.expectRevert(RuneraMarketplace.InvalidFee.selector);
        marketplace.setPlatformFee(1001); // Max is 1000 (10%)
    }

    function test_WithdrawFees() public {
        // Create sale to accumulate fees
        vm.prank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        vm.prank(seller);
        uint256 listingId = marketplace.createListing(ITEM_ID, 1, 1 ether);

        vm.prank(buyer);
        marketplace.buyItem{value: 1 ether}(listingId, 1);

        uint256 accumulatedFees = marketplace.getAccumulatedFees();
        uint256 adminBalanceBefore = admin.balance;

        vm.prank(admin);
        marketplace.withdrawFees(payable(admin));

        uint256 adminBalanceAfter = admin.balance;
        assertEq(adminBalanceAfter - adminBalanceBefore, accumulatedFees);
        assertEq(marketplace.getAccumulatedFees(), 0);
    }

    function test_WithdrawFeesNonAdminReverts() public {
        vm.prank(buyer);
        vm.expectRevert(RuneraMarketplace.Unauthorized.selector);
        marketplace.withdrawFees(payable(buyer));
    }

    // ========== Listing Query Tests ==========

    function test_GetListingsByItem() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        marketplace.createListing(ITEM_ID, 2, PRICE_PER_UNIT);
        marketplace.createListing(ITEM_ID, 3, PRICE_PER_UNIT);
        vm.stopPrank();

        uint256[] memory listings = marketplace.getListingsByItem(ITEM_ID);
        assertEq(listings.length, 2);
    }

    function test_GetListingsBySeller() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        marketplace.createListing(ITEM_ID, 2, PRICE_PER_UNIT);
        marketplace.createListing(ITEM_ID, 3, PRICE_PER_UNIT);
        vm.stopPrank();

        uint256[] memory listings = marketplace.getListingsBySeller(seller);
        assertEq(listings.length, 2);
    }

    function test_GetListingsFiltersInactive() public {
        vm.startPrank(seller);
        cosmeticNFT.setApprovalForAll(address(marketplace), true);

        uint256 listing1 = marketplace.createListing(
            ITEM_ID,
            2,
            PRICE_PER_UNIT
        );
        marketplace.createListing(ITEM_ID, 3, PRICE_PER_UNIT);

        marketplace.cancelListing(listing1);
        vm.stopPrank();

        uint256[] memory listings = marketplace.getListingsBySeller(seller);
        assertEq(listings.length, 1); // Only 1 active listing
    }
}
