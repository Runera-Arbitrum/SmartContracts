// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {
    IERC1155Receiver
} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IRuneraMarketplace} from "./interfaces/IRuneraMarketplace.sol";
import {RuneraAccessControl} from "./access/RuneraAccessControl.sol";
import {RuneraCosmeticNFT} from "./RuneraCosmeticNFT.sol";

/**
 * @title RuneraMarketplace
 * @notice Decentralized marketplace for trading Cosmetic NFTs
 * @dev Supports listings, buying, and platform fee collection
 *
 * Key Features:
 * - List cosmetic items for sale
 * - Buy with ETH payment
 * - Platform fee (default 5%)
 * - Seller can cancel anytime
 * - Fee withdrawal by admin
 *
 * Gas Optimizations:
 * - Packed Listing struct (4 slots)
 * - Uint64 for timestamps
 * - Cached role checks
 * - Minimal storage reads
 */
contract RuneraMarketplace is IRuneraMarketplace, IERC1155Receiver {
    /// @notice Reference to access control
    RuneraAccessControl public immutable accessControl;

    /// @notice Reference to cosmetic NFT contract
    RuneraCosmeticNFT public immutable cosmeticNFT;

    /// @notice Cached admin role
    bytes32 private immutable _cachedAdminRole;

    /// @notice Listing counter
    uint256 private _listingIdCounter;

    /// @notice Platform fee in basis points (500 = 5%)
    uint256 public platformFeeBps;

    /// @notice Accumulated platform fees
    uint256 public accumulatedFees;

    /// @notice All listings: listingId => Listing
    mapping(uint256 => Listing) private _listings;

    /// @notice Active listings by item: itemId => listingId[]
    mapping(uint256 => uint256[]) private _listingsByItem;

    /// @notice Active listings by seller: seller => listingId[]
    mapping(address => uint256[]) private _listingsBySeller;

    /// @notice Constants
    uint256 private constant MAX_FEE_BPS = 1000; // 10% max
    uint256 private constant BPS_DENOMINATOR = 10000;

    /// @notice Custom errors
    error InvalidPrice();
    error InvalidAmount();
    error InvalidFee();
    error ListingNotFound();
    error ListingNotActive();
    error NotSeller();
    error InsufficientPayment();
    error TransferFailed();
    error Unauthorized();

    /**
     * @notice Initialize marketplace
     * @param _accessControl Access control contract
     * @param _cosmeticNFT Cosmetic NFT contract
     */
    constructor(address _accessControl, address _cosmeticNFT) {
        accessControl = RuneraAccessControl(_accessControl);
        cosmeticNFT = RuneraCosmeticNFT(_cosmeticNFT);
        _cachedAdminRole = accessControl.DEFAULT_ADMIN_ROLE();

        platformFeeBps = 500; // 5% default fee
        _listingIdCounter = 1;
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function createListing(
        uint256 itemId,
        uint256 amount,
        uint256 pricePerUnit
    ) external returns (uint256 listingId) {
        if (amount == 0) revert InvalidAmount();
        if (pricePerUnit == 0) revert InvalidPrice();

        // Verify ownership
        require(
            cosmeticNFT.balanceOf(msg.sender, itemId) >= amount,
            "Insufficient balance"
        );

        listingId = _listingIdCounter++;

        _listings[listingId] = Listing({
            seller: msg.sender,
            itemId: itemId,
            amount: amount,
            pricePerUnit: pricePerUnit,
            status: ListingStatus.ACTIVE,
            createdAt: uint64(block.timestamp),
            soldAt: 0
        });

        // Add to indexes
        _listingsByItem[itemId].push(listingId);
        _listingsBySeller[msg.sender].push(listingId);

        // Transfer NFTs to marketplace (escrow)
        cosmeticNFT.safeTransferFrom(
            msg.sender,
            address(this),
            itemId,
            amount,
            ""
        );

        emit ListingCreated(
            listingId,
            msg.sender,
            itemId,
            amount,
            pricePerUnit
        );
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function cancelListing(uint256 listingId) external {
        Listing storage listing = _listings[listingId];

        if (listing.seller == address(0)) revert ListingNotFound();
        if (listing.seller != msg.sender) revert NotSeller();
        if (listing.status != ListingStatus.ACTIVE) revert ListingNotActive();

        listing.status = ListingStatus.CANCELLED;

        // Return NFTs to seller
        cosmeticNFT.safeTransferFrom(
            address(this),
            listing.seller,
            listing.itemId,
            listing.amount,
            ""
        );

        emit ListingCancelled(listingId, msg.sender);
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function buyItem(uint256 listingId, uint256 amount) external payable {
        Listing storage listing = _listings[listingId];

        if (listing.seller == address(0)) revert ListingNotFound();
        if (listing.status != ListingStatus.ACTIVE) revert ListingNotActive();
        if (amount == 0 || amount > listing.amount) revert InvalidAmount();

        uint256 totalPrice = listing.pricePerUnit * amount;
        if (msg.value < totalPrice) revert InsufficientPayment();

        // Calculate platform fee
        uint256 platformFee = (totalPrice * platformFeeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = totalPrice - platformFee;

        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.status = ListingStatus.SOLD;
            listing.soldAt = uint64(block.timestamp);
        }

        // Accumulate fee
        accumulatedFees += platformFee;

        // Transfer NFTs to buyer
        cosmeticNFT.safeTransferFrom(
            address(this),
            msg.sender,
            listing.itemId,
            amount,
            ""
        );

        // Pay seller
        (bool success, ) = payable(listing.seller).call{value: sellerProceeds}(
            ""
        );
        if (!success) revert TransferFailed();

        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = payable(msg.sender).call{
                value: msg.value - totalPrice
            }("");
            if (!refundSuccess) revert TransferFailed();
        }

        emit ItemSold(
            listingId,
            listing.seller,
            msg.sender,
            listing.itemId,
            amount,
            totalPrice,
            platformFee
        );
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function getListing(
        uint256 listingId
    ) external view returns (Listing memory listing) {
        listing = _listings[listingId];
        if (listing.seller == address(0)) revert ListingNotFound();
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function getListingsByItem(
        uint256 itemId
    ) external view returns (uint256[] memory listingIds) {
        uint256[] storage allListings = _listingsByItem[itemId];

        // Count active listings
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allListings.length; i++) {
            if (_listings[allListings[i]].status == ListingStatus.ACTIVE) {
                activeCount++;
            }
        }

        // Build active listings array
        listingIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allListings.length; i++) {
            if (_listings[allListings[i]].status == ListingStatus.ACTIVE) {
                listingIds[index++] = allListings[i];
            }
        }
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function getListingsBySeller(
        address seller
    ) external view returns (uint256[] memory listingIds) {
        uint256[] storage allListings = _listingsBySeller[seller];

        // Count active listings
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allListings.length; i++) {
            if (_listings[allListings[i]].status == ListingStatus.ACTIVE) {
                activeCount++;
            }
        }

        // Build active listings array
        listingIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allListings.length; i++) {
            if (_listings[allListings[i]].status == ListingStatus.ACTIVE) {
                listingIds[index++] = allListings[i];
            }
        }
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function getPlatformFee() external view returns (uint256 fee) {
        return platformFeeBps;
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function setPlatformFee(uint256 newFee) external {
        if (!accessControl.hasRole(_cachedAdminRole, msg.sender)) {
            revert Unauthorized();
        }
        if (newFee > MAX_FEE_BPS) revert InvalidFee();

        uint256 oldFee = platformFeeBps;
        platformFeeBps = newFee;

        emit PlatformFeeUpdated(oldFee, newFee);
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function withdrawFees(address payable to) external {
        if (!accessControl.hasRole(_cachedAdminRole, msg.sender)) {
            revert Unauthorized();
        }

        uint256 amount = accumulatedFees;
        accumulatedFees = 0;

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(to, amount);
    }

    /**
     * @inheritdoc IRuneraMarketplace
     */
    function getAccumulatedFees() external view returns (uint256 amount) {
        return accumulatedFees;
    }

    /**
     * @dev ERC1155 receiver implementation
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev ERC1155 batch receiver implementation
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev ERC165 support
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
