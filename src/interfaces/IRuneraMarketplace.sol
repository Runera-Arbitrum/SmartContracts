// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRuneraMarketplace
 * @notice Interface for Runera Marketplace contract
 * @dev Trading platform for Cosmetic NFTs with platform fees
 */
interface IRuneraMarketplace {
    /// @notice Listing status
    enum ListingStatus {
        ACTIVE,
        SOLD,
        CANCELLED
    }

    /// @notice Marketplace listing
    struct Listing {
        address seller;
        uint256 itemId;
        uint256 amount; // Quantity listed
        uint256 pricePerUnit; // Price in wei per NFT
        ListingStatus status;
        uint64 createdAt;
        uint64 soldAt;
    }

    /// @notice Listing created event
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed itemId,
        uint256 amount,
        uint256 pricePerUnit
    );

    /// @notice Listing cancelled event
    event ListingCancelled(uint256 indexed listingId, address indexed seller);

    /// @notice Item sold event
    event ItemSold(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer,
        uint256 itemId,
        uint256 amount,
        uint256 totalPrice,
        uint256 platformFee
    );

    /// @notice Platform fee updated event
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Platform fee withdrawn event
    event FeesWithdrawn(address indexed to, uint256 amount);

    /**
     * @notice Create a new listing
     * @param itemId Cosmetic item ID to sell
     * @param amount Quantity to sell
     * @param pricePerUnit Price per NFT in wei
     * @return listingId Created listing ID
     */
    function createListing(
        uint256 itemId,
        uint256 amount,
        uint256 pricePerUnit
    ) external returns (uint256 listingId);

    /**
     * @notice Cancel an active listing
     * @param listingId Listing to cancel
     */
    function cancelListing(uint256 listingId) external;

    /**
     * @notice Buy items from listing
     * @param listingId Listing to buy from
     * @param amount Quantity to buy
     */
    function buyItem(uint256 listingId, uint256 amount) external payable;

    /**
     * @notice Get listing details
     * @param listingId Listing identifier
     * @return listing Listing data
     */
    function getListing(
        uint256 listingId
    ) external view returns (Listing memory listing);

    /**
     * @notice Get active listings for an item
     * @param itemId Cosmetic item ID
     * @return listingIds Array of active listing IDs
     */
    function getListingsByItem(
        uint256 itemId
    ) external view returns (uint256[] memory listingIds);

    /**
     * @notice Get user's active listings
     * @param seller Seller address
     * @return listingIds Array of listing IDs
     */
    function getListingsBySeller(
        address seller
    ) external view returns (uint256[] memory listingIds);

    /**
     * @notice Get current platform fee percentage
     * @return fee Fee in basis points (e.g., 500 = 5%)
     */
    function getPlatformFee() external view returns (uint256 fee);

    /**
     * @notice Set platform fee (admin only)
     * @param newFee New fee in basis points
     */
    function setPlatformFee(uint256 newFee) external;

    /**
     * @notice Withdraw accumulated platform fees (admin only)
     * @param to Recipient address
     */
    function withdrawFees(address payable to) external;

    /**
     * @notice Get accumulated platform fees
     * @return amount Fee balance
     */
    function getAccumulatedFees() external view returns (uint256 amount);
}
