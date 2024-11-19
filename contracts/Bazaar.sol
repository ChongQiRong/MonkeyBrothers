// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Monkey.sol";
import "./Monk.sol";
import "./Ownable.sol";

contract Bazaar is Ownable {
    Monkeys public monkeyContract;
    Monk public monkToken;
    
    uint256 public commissionFee;
    uint256 public priceUpdateCooldown = 1 hours;
    
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
        uint256 lastPriceUpdate;
    }
    
    // TokenId => Listing
    mapping(uint256 => Listing) public listings;
    
    // Total fees collected
    uint256 public totalFees;
    
    event MonkeyListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event MonkeyDelisted(uint256 indexed tokenId, address indexed seller);
    event MonkeySold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event CommissionFeeUpdated(uint256 oldFee, uint256 newFee);
    event PriceUpdated(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
    event CooldownPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    
    constructor(address _monkeyContract, address _monkToken) {
        monkeyContract = Monkeys(_monkeyContract);
        monkToken = Monk(_monkToken);
        commissionFee = 0.01 ether; // Initial fee 
        priceUpdateCooldown = 1 hours; // Initial cooldown period
    }
    
    /**
     * @dev Update commission fee - only owner
     * @param newFee New commission fee amount
     */
    function updateCommissionFee(uint256 newFee) external onlyOwner {
        require(newFee > 0, "Fee must be greater than 0");
        uint256 oldFee = commissionFee;
        commissionFee = newFee;
        emit CommissionFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev List a Monkey for sale
     * @param tokenId The ID of the Monkey to list
     * @param price The price in MONK tokens
     */
    function listMonkey(uint256 tokenId, uint256 price) external {
        require(monkeyContract.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(!listings[tokenId].isActive, "Already listed");
        require(price > 0, "Price must be greater than 0");
        
        // Check if seller has approved enough MONK for the commission fee
        require(monkToken.allowance(msg.sender, address(this)) >= commissionFee, "Insufficient MONK allowance for fee");
        
        // Check if seller has approved the NFT transfer
        require(monkeyContract.getApproved(tokenId) == address(this) || monkeyContract.isApprovedForAll(msg.sender, address(this)), 
                "NFT not approved for transfer");
        
        // Transfer commission fee
        require(monkToken.transferFrom(msg.sender, address(this), commissionFee), "Fee transfer failed");
        
        // Transfer Monkey to contract
        monkeyContract.transferFrom(msg.sender, address(this), tokenId);
        
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true,
            lastPriceUpdate: block.timestamp
        });
        
        emit MonkeyListed(tokenId, msg.sender, price);
    }
    
    /**
     * @dev List multiple Monkeys for sale
     * @param tokenIds Array of Monkey IDs to list
     * @param prices Array of prices for each Monkey
     */
    function listMultipleMonkeys(uint256[] calldata tokenIds, uint256[] calldata prices) external {
        require(tokenIds.length == prices.length, "Arrays length mismatch");
        require(tokenIds.length > 0, "Empty arrays");
        
        uint256 totalFee = commissionFee * tokenIds.length;
        require(monkToken.allowance(msg.sender, address(this)) >= totalFee, "Insufficient MONK allowance for fees");
        
        // Transfer total commission fees upfront
        require(monkToken.transferFrom(msg.sender, address(this), totalFee), "Fees transfer failed");
        
        for(uint i = 0; i < tokenIds.length; i++) {
            require(monkeyContract.ownerOf(tokenIds[i]) == msg.sender, "Not the owner");
            require(!listings[tokenIds[i]].isActive, "Monkey already listed");
            require(prices[i] > 0, "Price must be greater than 0");
            
            // Transfer Monkey to contract
            monkeyContract.transferFrom(msg.sender, address(this), tokenIds[i]);
            
            listings[tokenIds[i]] = Listing({
                seller: msg.sender,
                price: prices[i],
                isActive: true,
                lastPriceUpdate: block.timestamp
            });
            
            emit MonkeyListed(tokenIds[i], msg.sender, prices[i]);
        }
    }
    
    /**
     * @dev Delist a Monkey from sale
     * @param tokenId The ID of the Monkey to delist
     */
    function delistMonkey(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "Not listed");
        require(listing.seller == msg.sender, "Not the seller");
        
        // Return commission fee
        require(monkToken.transfer(msg.sender, commissionFee), "Fee return failed");
        
        // Return Monkey
        monkeyContract.transferFrom(address(this), msg.sender, tokenId);
        
        delete listings[tokenId];
        
        emit MonkeyDelisted(tokenId, msg.sender);
    }
    
    /**
     * @dev Buy a listed Monkey
     * @param tokenId The ID of the Monkey to buy
     */
    function buyMonkey(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "Not listed");
        require(msg.sender != listing.seller, "Cannot buy own listing");
        
        uint256 totalPrice = listing.price + commissionFee;
        
        // Check if buyer has enough MONK and has approved the transfer
        require(monkToken.balanceOf(msg.sender) >= totalPrice, "Insufficient MONK balance");
        require(monkToken.allowance(msg.sender, address(this)) >= totalPrice, "Insufficient MONK allowance");
        
        // Transfer payment to seller
        require(monkToken.transferFrom(msg.sender, listing.seller, listing.price), "Payment transfer failed");
        
        // Transfer commission fee
        require(monkToken.transferFrom(msg.sender, address(this), commissionFee), "Fee transfer failed");
        
        // Transfer Monkey to buyer
        monkeyContract.transferFrom(address(this), msg.sender, tokenId);
        
        totalFees += commissionFee;
        delete listings[tokenId];
        
        emit MonkeySold(tokenId, listing.seller, msg.sender, listing.price);
    }
    
    /**
     * @dev Update the price of a listed Monkey
     * @param tokenId The ID of the Monkey
     * @param newPrice The new price
     */
    function updateListingPrice(uint256 tokenId, uint256 newPrice) external {
        Listing storage listing = listings[tokenId];
        require(listing.isActive, "Not listed");
        require(listing.seller == msg.sender, "Not the seller");
        require(newPrice > 0, "Price must be greater than 0");
        require(block.timestamp >= listing.lastPriceUpdate + priceUpdateCooldown, "Price update cooldown active");
        
        uint256 oldPrice = listing.price;
        listing.price = newPrice;
        listing.lastPriceUpdate = block.timestamp;
        
        emit PriceUpdated(tokenId, oldPrice, newPrice);
    }

    /**
    * @dev Update price update cooldown period - only owner
    * @param newCooldown New cooldown period in seconds
    */
    function updatePriceUpdateCooldown(uint256 newCooldown) external onlyOwner {
        require(newCooldown > 0, "Cooldown must be greater than 0");
        uint256 oldCooldown = priceUpdateCooldown;
        priceUpdateCooldown = newCooldown;
        emit CooldownPeriodUpdated(oldCooldown, newCooldown);
    }    
    
    /**
     * @dev Withdraw accumulated fees - only owner
     */
    function withdrawFees() external onlyOwner {
        uint256 amount = totalFees;
        require(amount > 0, "No fees to withdraw");
        
        totalFees = 0;
        require(monkToken.transfer(owner(), amount), "Fee withdrawal failed");
        
        emit FeesWithdrawn(owner(), amount);
    }
    
    /**
     * @dev Check if a Monkey is listed
     * @param tokenId The ID of the Monkey
     */
    function isListed(uint256 tokenId) external view returns (bool) {
        return listings[tokenId].isActive;
    }
    
    /**
     * @dev Get listing details
     * @param tokenId The ID of the Monkey
     */
    function getListingDetails(uint256 tokenId) external view 
        returns (
            address seller, 
            uint256 price, 
            bool isActive, 
            uint256 lastPriceUpdate
        ) 
    {
        Listing memory listing = listings[tokenId];
        return (
            listing.seller, 
            listing.price, 
            listing.isActive, 
            listing.lastPriceUpdate
        );
    }
    
    /**
     * @dev Check if price update is allowed for a token
     * @param tokenId The ID of the Monkey
     */
    function canUpdatePrice(uint256 tokenId) external view returns (bool) {
        Listing memory listing = listings[tokenId];
        return listing.isActive && 
               block.timestamp >= listing.lastPriceUpdate + priceUpdateCooldown;
    }
}