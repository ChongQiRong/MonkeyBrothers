// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Monkey.sol";
import "./Monk.sol";
import "./Ownable.sol";

/**
 * @title Bazaar
 * @author MonkeyBrothers
 * @notice This contract implements a marketplace for trading Monkey NFTs
 * @dev Handles listings, auctions, and trades of Monkey NFTs using Monk tokens as currency
 */
contract Bazaar is Ownable {
    Monkeys public monkeyContract;
    Monk public monkToken;

    /// @notice Commission rate in basis points (2%)
    uint256 public constant COMMISSION_RATE = 200;
    /// @notice Duration of auctions in seconds (12 hours)
    uint256 public constant AUCTION_DURATION = 12 hours;

    /// @notice Total trading volume in Monk tokens
    uint256 public totalVolume;
    /// @notice Current floor price of listed Monkeys
    uint256 public floorPrice;
    /// @notice Highest current offer across all listings
    uint256 public bestOffer;
    /// @notice Total number of active listings
    uint256 public totalListings;
    /// @notice Total fees collected from trades
    uint256 public totalFees;

    /**
     * @notice Structure for marketplace listings
     * @param seller Address of the Monkey owner
     * @param buyNowPrice Instant purchase price
     * @param startingBidPrice Minimum bid price for auction
     * @param highestBid Current highest bid
     * @param highestBidder Address of highest bidder
     * @param auctionEndTime Timestamp when auction ends
     * @param isActive Whether listing is currently active
     * @param isAuction Whether listing is auction format
     */
    struct Listing {
        address seller;
        uint256 buyNowPrice;
        uint256 startingBidPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 auctionEndTime;
        bool isActive;
        bool isAuction;
    }

    /**
     * @notice Structure for marketplace metrics
     * @param totalVolume Total trading volume
     * @param floorPrice Lowest listed price
     * @param bestOffer Highest current bid
     * @param percentageListed Percentage of total Monkeys listed
     * @param uniqueOwners Number of unique Monkey holders
     */
    struct MarketMetrics {
        uint256 totalVolume;
        uint256 floorPrice;
        uint256 bestOffer;
        uint256 percentageListed;
        uint256 uniqueOwners;
    }

    /// @notice Maps token IDs to their listing information
    /// @dev Stores all active and inactive listings
    mapping(uint256 => Listing) public listings;

    /// @notice Maps addresses to their owned NFT count
    /// @dev Tracks how many Monkeys each address owns
    mapping(address => uint256) public ownershipCount;

    /// @notice Maps bidders and token IDs to bid amounts
    /// @dev Two-level mapping tracking all bids: bidder => tokenId => amount
    mapping(address => mapping(uint256 => uint256)) public bids;

    /// @notice Emitted when a Monkey is listed on the marketplace
    /// @param tokenId The ID of the listed Monkey
    /// @param seller The address of the seller
    /// @param buyNowPrice The instant purchase price
    /// @param startingBidPrice The minimum bid price for auction
    event MonkeyListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 buyNowPrice,
        uint256 startingBidPrice
    );

    /// @notice Emitted when a Monkey is removed from the marketplace
    /// @param tokenId The ID of the delisted Monkey
    /// @param seller The address of the seller
    event MonkeyDelisted(uint256 indexed tokenId, address indexed seller);

    /// @notice Emitted when a Monkey is sold via buy now
    /// @param tokenId The ID of the sold Monkey
    /// @param seller The address of the seller
    /// @param buyer The address of the buyer
    /// @param price The final sale price
    event MonkeySold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    /// @notice Emitted when a bid is placed on a Monkey
    /// @param tokenId The ID of the Monkey
    /// @param bidder The address of the bidder
    /// @param amount The bid amount
    event BidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );

    /// @notice Emitted when an auction ends
    /// @param tokenId The ID of the Monkey
    /// @param winner The address of the auction winner
    /// @param winningBid The winning bid amount
    event AuctionEnded(
        uint256 indexed tokenId,
        address indexed winner,
        uint256 winningBid
    );

    /// @notice Emitted when marketplace metrics are updated
    /// @param totalVolume Updated total trading volume
    /// @param floorPrice Updated floor price
    /// @param bestOffer Updated highest bid
    /// @param percentageListed Updated percentage of total Monkeys listed
    /// @param uniqueOwners Updated number of unique owners
    event MetricsUpdated(
        uint256 totalVolume,
        uint256 floorPrice,
        uint256 bestOffer,
        uint256 percentageListed,
        uint256 uniqueOwners
    );

    /// @notice Emitted when accumulated fees are withdrawn
    /// @param owner Address receiving the fees
    /// @param amount Amount of fees withdrawn
    event FeesWithdrawn(address indexed owner, uint256 amount);

    /**
     * @notice Initializes the Bazaar marketplace
     * @dev Sets up contract references and initializes floor price to maximum value
     * @param _monkeyContract Address of the Monkeys NFT contract
     * @param _monkToken Address of the Monk token contract
     */
    constructor(address _monkeyContract, address _monkToken) {
        require(
            _monkeyContract != address(0) && _monkToken != address(0),
            "Invalid addresses"
        );
        monkeyContract = Monkeys(_monkeyContract);
        monkToken = Monk(_monkToken);
        floorPrice = type(uint256).max; // Initialize to max value
    }

    /**
     * @notice Lists a Monkey for sale with auction and buy now options
     * @dev Transfers NFT to contract and creates listing
     * @param tokenId The ID of the Monkey to list
     * @param buyNowPrice The instant purchase price
     * @param startingBidPrice The minimum bid price for auction
     */
    function listMonkey(
        uint256 tokenId,
        uint256 buyNowPrice,
        uint256 startingBidPrice
    ) external {
        require(monkeyContract.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(!listings[tokenId].isActive, "Already listed");
        require(buyNowPrice > 0, "Buy now price must be greater than 0");
        require(
            startingBidPrice < buyNowPrice,
            "Starting bid must be lower than buy now price"
        );

        // Check approval for NFT transfer
        require(
            monkeyContract.getApproved(tokenId) == address(this) ||
                monkeyContract.isApprovedForAll(msg.sender, address(this)),
            "NFT not approved for transfer"
        );

        // Transfer NFT to contract
        monkeyContract.transferFrom(msg.sender, address(this), tokenId);

        // Create listing
        listings[tokenId] = Listing({
            seller: msg.sender,
            buyNowPrice: buyNowPrice,
            startingBidPrice: startingBidPrice,
            highestBid: 0,
            highestBidder: address(0),
            auctionEndTime: block.timestamp + AUCTION_DURATION,
            isActive: true,
            isAuction: true
        });

        totalListings++;
        if (buyNowPrice < floorPrice) {
            floorPrice = buyNowPrice;
        }

        emit MonkeyListed(tokenId, msg.sender, buyNowPrice, startingBidPrice);
        _updateMetrics();
    }

    /**
     * @notice Removes a Monkey listing from the marketplace
     * @dev Returns NFT to seller if no bids exist
     * @param tokenId The ID of the Monkey to delist
     */
    function delistMonkey(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.isActive, "Not listed");
        require(listing.seller == msg.sender, "Not the seller");

        if (listing.isAuction) {
            require(listing.highestBid == 0, "Cannot delist: has bids");
        }

        // Return NFT to seller
        monkeyContract.transferFrom(address(this), msg.sender, tokenId);

        // Update metrics
        totalListings--;
        if (listing.buyNowPrice == floorPrice) {
            _updateFloorPrice();
        }

        delete listings[tokenId];
        emit MonkeyDelisted(tokenId, msg.sender);
        _updateMetrics();
    }

    /**
     * @notice Places a bid on a listed Monkey
     * @dev Handles bid transfers and updates highest bid
     * @param tokenId The ID of the Monkey to bid on
     * @param bidAmount The amount of MONK tokens to bid
     */
    function placeBid(uint256 tokenId, uint256 bidAmount) external {
        Listing storage listing = listings[tokenId];
        require(listing.isActive && listing.isAuction, "Not an active auction");
        require(block.timestamp < listing.auctionEndTime, "Auction has ended");
        require(
            bidAmount >= listing.startingBidPrice,
            "Bid below starting price"
        );
        require(
            bidAmount > listing.highestBid,
            "Bid not higher than current bid"
        );
        require(msg.sender != listing.seller, "Cannot bid on own listing");

        // Check allowance and balance
        require(
            monkToken.allowance(msg.sender, address(this)) >= bidAmount,
            "Insufficient allowance"
        );
        require(
            monkToken.balanceOf(msg.sender) >= bidAmount,
            "Insufficient balance"
        );

        // Return previous bid if exists
        if (listing.highestBid > 0) {
            monkToken.transfer(listing.highestBidder, listing.highestBid);
        }

        // Transfer new bid amount to contract
        require(
            monkToken.transferFrom(msg.sender, address(this), bidAmount),
            "Bid transfer failed"
        );

        listing.highestBid = bidAmount;
        listing.highestBidder = msg.sender;

        if (bidAmount > bestOffer) {
            bestOffer = bidAmount;
        }

        emit BidPlaced(tokenId, msg.sender, bidAmount);
    }

    /**
     * @notice Finalizes an auction after its end time
     * @dev Transfers NFT and payments, updates metrics
     * @param tokenId The ID of the Monkey auction to finalize
     */
    function finalizeAuction(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.isActive && listing.isAuction, "Not an active auction");
        require(
            block.timestamp >= listing.auctionEndTime,
            "Auction still ongoing"
        );

        if (listing.highestBidder != address(0)) {
            // Calculate commission
            uint256 commission = (listing.highestBid * COMMISSION_RATE) / 10000;
            uint256 sellerPayment = listing.highestBid - commission;

            // Transfer payment to seller
            monkToken.transfer(listing.seller, sellerPayment);

            // Transfer NFT to winner
            monkeyContract.transferFrom(
                address(this),
                listing.highestBidder,
                tokenId
            );

            totalFees += commission;
            totalVolume += listing.highestBid;
            emit AuctionEnded(
                tokenId,
                listing.highestBidder,
                listing.highestBid
            );
        } else {
            // Return NFT to seller if no bids
            monkeyContract.transferFrom(address(this), listing.seller, tokenId);
        }

        totalListings--;
        delete listings[tokenId];
        _updateMetrics();
    }

    /**
     * @notice Purchases a Monkey at its buy now price
     * @dev Handles payment transfers and updates metrics
     * @param tokenId The ID of the Monkey to purchase
     */
    function buyNow(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "Not listed");
        require(msg.sender != listing.seller, "Cannot buy own listing");

        uint256 commission = (listing.buyNowPrice * COMMISSION_RATE) / 10000;
        uint256 sellerPayment = listing.buyNowPrice - commission;

        // Transfer full amount to contract first
        require(
            monkToken.transferFrom(
                msg.sender,
                address(this),
                listing.buyNowPrice
            ),
            "Full transfer failed"
        );

        // Explicit transfers with error handling
        require(
            monkToken.transfer(listing.seller, sellerPayment),
            "Seller payment transfer failed"
        );
        require(
            monkToken.transfer(address(this), commission),
            "Commission transfer failed"
        );
        // // Transfer payment to seller
        // require(
        //     monkToken.transferFrom(msg.sender, listing.seller, sellerPayment),
        //     "Payment transfer failed"
        // );
        // // Transfer commission
        // require(
        //     monkToken.transferFrom(msg.sender, address(this), commission),
        //     "Commission transfer failed"
        // );

        // Transfer NFT to buyer
        monkeyContract.transferFrom(address(this), msg.sender, tokenId);

        totalFees += commission;
        totalVolume += listing.buyNowPrice;
        totalListings--;

        // Refund highest bidder if exists
        if (listing.highestBid > 0) {
            monkToken.transfer(listing.highestBidder, listing.highestBid);
        }

        emit MonkeySold(
            tokenId,
            listing.seller,
            msg.sender,
            listing.buyNowPrice
        );
        delete listings[tokenId];
        _updateMetrics();
    }

    /**
     * @notice Updates marketplace metrics after changes
     * @dev Calculates and emits updated market statistics
     */
    function _updateMetrics() internal {
        uint256 totalMinted = monkeyContract.getTotalMinted();
        uint256 percentageListed = totalMinted > 0
            ? (totalListings * 100) / totalMinted
            : 0;

        uint256 uniqueOwners = _countUniqueOwners(totalMinted);

        emit MetricsUpdated(
            totalVolume,
            floorPrice,
            bestOffer,
            percentageListed,
            uniqueOwners
        );
    }

    /**
     * @notice Updates the floor price after changes to listings
     * @dev Scans all active listings to find new floor price
     */
    function _updateFloorPrice() internal {
        uint256 newFloorPrice = type(uint256).max;
        uint256 totalMinted = monkeyContract.getTotalMinted();

        for (uint256 i = 0; i < totalMinted; i++) {
            if (
                listings[i].isActive && listings[i].buyNowPrice < newFloorPrice
            ) {
                newFloorPrice = listings[i].buyNowPrice;
            }
        }

        if (newFloorPrice != type(uint256).max) {
            floorPrice = newFloorPrice;
        }
    }

    /**
     * @notice Retrieves current marketplace metrics
     * @dev Calculates real-time market statistics
     * @return MarketMetrics struct containing current market data
     */
    function getMarketMetrics() external view returns (MarketMetrics memory) {
        uint256 totalMinted = monkeyContract.getTotalMinted();
        uint256 percentageListed = totalMinted > 0
            ? (totalListings * 100) / totalMinted
            : 0;

        return
            MarketMetrics({
                totalVolume: totalVolume,
                floorPrice: floorPrice,
                bestOffer: bestOffer,
                percentageListed: percentageListed,
                uniqueOwners: _countUniqueOwners(totalMinted)
            });
    }

    /**
     * @notice Counts unique Monkey owners
     * @dev Iterates through all Monkeys to find unique addresses
     * @param totalSupply Total number of minted Monkeys
     * @return Number of unique addresses holding Monkeys
     */
    function _countUniqueOwners(
        uint256 totalSupply
    ) internal view returns (uint256) {
        address[] memory owners = new address[](totalSupply);
        uint256 count = 0;

        // Collect all owners
        for (uint256 i = 0; i < totalSupply; i++) {
            address owner = monkeyContract.ownerOf(i);
            bool isNew = true;

            // Check if owner is already in our array
            for (uint256 j = 0; j < count; j++) {
                if (owners[j] == owner) {
                    isNew = false;
                    break;
                }
            }

            if (isNew) {
                owners[count] = owner;
                count++;
            }
        }

        return count;
    }

    /**
     * @notice Retrieves detailed information about a listing
     * @dev Returns all listing parameters
     * @param tokenId The ID of the Monkey listing to query
     * @return seller Address of the seller
     * @return buyNowPrice Instant purchase price
     * @return startingBidPrice Minimum bid price
     * @return highestBid Current highest bid
     * @return highestBidder Address of highest bidder
     * @return auctionEndTime Timestamp when auction ends
     * @return isActive Whether listing is active
     * @return isAuction Whether listing is auction format
     */
    function getListingDetails(
        uint256 tokenId
    )
        external
        view
        returns (
            address seller,
            uint256 buyNowPrice,
            uint256 startingBidPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 auctionEndTime,
            bool isActive,
            bool isAuction
        )
    {
        Listing memory listing = listings[tokenId];
        return (
            listing.seller,
            listing.buyNowPrice,
            listing.startingBidPrice,
            listing.highestBid,
            listing.highestBidder,
            listing.auctionEndTime,
            listing.isActive,
            listing.isAuction
        );
    }

    /**
     * @notice Withdraws accumulated marketplace fees
     * @dev Only callable by contract owner
     */
    function withdrawFees() external onlyOwner {
        uint256 amount = totalFees;
        require(amount > 0, "No fees to withdraw");
        totalFees = 0;
        require(monkToken.transfer(owner(), amount), "Fee withdrawal failed");
        emit FeesWithdrawn(owner(), amount);
    }
}
