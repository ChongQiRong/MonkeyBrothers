// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Monkey.sol";
import "./Monk.sol";
import "./Ownable.sol";

contract Bazaar is Ownable {
    Monkeys public monkeyContract;
    Monk public monkToken;

    uint256 public constant COMMISSION_RATE = 200; // 2% (in basis points)
    uint256 public constant AUCTION_DURATION = 12 hours;
    uint256 public totalVolume;
    uint256 public floorPrice;
    uint256 public bestOffer;
    uint256 public totalListings;
    uint256 public totalFees;

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

    struct MarketMetrics {
        uint256 totalVolume;
        uint256 floorPrice;
        uint256 bestOffer;
        uint256 percentageListed;
        uint256 uniqueOwners;
    }

    // TokenId => Listing
    mapping(uint256 => Listing) public listings;
    // Address => number of NFTs owned
    mapping(address => uint256) public ownershipCount;
    // Bidder => TokenId => Bid amount
    mapping(address => mapping(uint256 => uint256)) public bids;

    event MonkeyListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 buyNowPrice,
        uint256 startingBidPrice
    );

    event MonkeyDelisted(uint256 indexed tokenId, address indexed seller);

    event MonkeySold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    event BidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );

    event AuctionEnded(
        uint256 indexed tokenId,
        address indexed winner,
        uint256 winningBid
    );

    event MetricsUpdated(
        uint256 totalVolume,
        uint256 floorPrice,
        uint256 bestOffer,
        uint256 percentageListed,
        uint256 uniqueOwners
    );

    event FeesWithdrawn(address indexed owner, uint256 amount);

    constructor(address _monkeyContract, address _monkToken) {
        require(
            _monkeyContract != address(0) && _monkToken != address(0),
            "Invalid addresses"
        );
        monkeyContract = Monkeys(_monkeyContract);
        monkToken = Monk(_monkToken);
        floorPrice = type(uint256).max; // Initialize to max value
    }

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

    function buyNow(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "Not listed");
        require(msg.sender != listing.seller, "Cannot buy own listing");

        uint256 commission = (listing.buyNowPrice * COMMISSION_RATE) / 10000;
        uint256 sellerPayment = listing.buyNowPrice - commission;

        // Transfer payment to seller
        require(
            monkToken.transferFrom(msg.sender, listing.seller, sellerPayment),
            "Payment transfer failed"
        );
        // Transfer commission
        require(
            monkToken.transferFrom(msg.sender, address(this), commission),
            "Commission transfer failed"
        );

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

    function withdrawFees() external onlyOwner {
        uint256 amount = totalFees;
        require(amount > 0, "No fees to withdraw");
        totalFees = 0;
        require(monkToken.transfer(owner(), amount), "Fee withdrawal failed");
        emit FeesWithdrawn(owner(), amount);
    }
}
