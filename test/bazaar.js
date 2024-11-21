const truffleAssert = require("truffle-assertions");
const BigNumber = require("bignumber.js");
var assert = require("assert");

const Monk = artifacts.require("Monk");
const Monkeys = artifacts.require("Monkeys");
const MonkeyGacha = artifacts.require("MonkeyGacha");
const Bazaar = artifacts.require("Bazaar");

contract("Bazaar", (accounts) => {
    let monkInstance;
    let monkeysInstance;
    let gachaInstance;
    let bazaarInstance;

    const [owner, player1, player2, player3] = accounts;
    let initialMonkBalance;
    const PRICE_BASE = "10";
    const START_BID = "1";
    const PRICE_IN_WEI = web3.utils.toWei(PRICE_BASE, "ether"); // 10 MONK
    const START_BID_IN_WEI = web3.utils.toWei(START_BID, "ether"); // 1 MONK
    let player1TokenIds = []; // Array to store player1's token IDs

    before(async () => {
        monkInstance = await Monk.deployed();
        monkeysInstance = await Monkeys.deployed();
        gachaInstance = await MonkeyGacha.deployed();
        bazaarInstance = await Bazaar.deployed();

        await monkeysInstance.setGachaContract(gachaInstance.address);

        await monkInstance.getMonks({
            from: player1,
            value: web3.utils.toWei("1", "ether"), //1000 MONK
        });
        await monkInstance.getMonks({
            from: player2,
            value: web3.utils.toWei("1", "ether"),
        });
        await monkInstance.getMonks({
            from: player3,
            value: web3.utils.toWei("2", "ether"),
        });

        await monkInstance.giveMonkApproval(gachaInstance.address, 1000, {
            from: player1,
        });
        await monkInstance.giveMonkApproval(gachaInstance.address, 1000, {
            from: player2,
        });
        await monkInstance.giveMonkApproval(gachaInstance.address, 2000, {
            from: player3,
        });

        // Draw monkeys and store their IDs
        const draw1 = await gachaInstance.drawMonkey({from: player1});
        const tokenId1 = draw1.logs.find((log) => log.event === "MonkeyDrawn").args.tokenId.toNumber();
        player1TokenIds.push(tokenId1);

        const draw2 = await gachaInstance.drawMonkey({from: player1});
        const tokenId2 = draw2.logs.find((log) => log.event === "MonkeyDrawn").args.tokenId.toNumber();
        player1TokenIds.push(tokenId2);

        const draw3 = await gachaInstance.drawMonkey({from: player1});
        const tokenId3 = draw3.logs.find((log) => log.event === "MonkeyDrawn").args.tokenId.toNumber();
        player1TokenIds.push(tokenId3);

        initialMonkBalance = await monkInstance.checkMonks({from: player1});
    });

    describe("Listing", () => {
        it("should fail to list monkey without approval", async () => {
            await truffleAssert.reverts(
                bazaarInstance.listMonkey(player1TokenIds[0], PRICE_IN_WEI, START_BID_IN_WEI, {
                    from: player1,
                }),
                "NFT not approved for transfer"
            );
        });

        it("should fail listing when sender is not owner", async () => {
            await truffleAssert.reverts(
                bazaarInstance.listMonkey(player1TokenIds[0], PRICE_IN_WEI, START_BID_IN_WEI, {from: player2}),
                "Not the owner"
            );
        });

        it("should emit correct event on successful listing", async () => {
            await monkeysInstance.setApprovalForAll(bazaarInstance.address, true, {
                from: player1,
            });

            const result = await bazaarInstance.listMonkey(player1TokenIds[0], PRICE_IN_WEI, START_BID_IN_WEI, {
                from: player1,
            });

            truffleAssert.eventEmitted(result, "MonkeyListed", (ev) => {
                return (
                    ev.tokenId.toNumber() === player1TokenIds[0] &&
                    ev.seller === player1 &&
                    ev.buyNowPrice.toString() === PRICE_IN_WEI
                );
            });
        });

        it("should update market metrics after listing", async () => {
            const metrics = await bazaarInstance.getMarketMetrics();
            const totalListingsCount = await bazaarInstance.totalListings();
            assert.equal(totalListingsCount.toString(), "1", "Should have 1 listing");
            assert.equal(metrics.floorPrice.toString(), PRICE_IN_WEI, "Floor price should match listing");
        });

        it("should handle multiple simultaneous listings correctly", async () => {
            await bazaarInstance.listMonkey(player1TokenIds[1], web3.utils.toWei("20", "ether"), START_BID_IN_WEI, {
                from: player1,
            });

            const metrics = await bazaarInstance.getMarketMetrics();
            const totalListingsCount = await bazaarInstance.totalListings();
            assert.equal(metrics.floorPrice.toString(), PRICE_IN_WEI, "Floor price should be lowest listing");
            assert.equal(totalListingsCount.toString(), "2", "Should have 2 listings");
        });

        it("should fail listing already listed monkey", async () => {
            await truffleAssert.reverts(
                bazaarInstance.listMonkey(player1TokenIds[0], PRICE_IN_WEI, START_BID_IN_WEI, {from: player1}),
                "Not the owner"
            );
        });
    });

    describe("Bidding", () => {
        before(async () => {
            // Approve bazaar for MONK transfers
            await monkInstance.giveMonkApproval(bazaarInstance.address, 2000, {from: player2});
            await monkInstance.giveMonkApproval(bazaarInstance.address, 2000, {from: player3});
        });

        it("should allow placing a valid bid", async () => {
            const bidAmount = web3.utils.toWei("2", "ether"); // 2 MONK
            const result = await bazaarInstance.placeBid(player1TokenIds[0], bidAmount, {from: player2});

            truffleAssert.eventEmitted(result, "BidPlaced", (ev) => {
                return (
                    ev.tokenId.toNumber() === player1TokenIds[0] &&
                    ev.bidder === player2 &&
                    ev.amount.toString() === bidAmount
                );
            });
        });

        it("should fail bid below starting price", async () => {
            const lowBid = web3.utils.toWei("0.5", "ether"); // 0.5 MONK
            await truffleAssert.reverts(
                bazaarInstance.placeBid(player1TokenIds[0], lowBid, {
                    from: player3,
                }),
                "Bid below starting price"
            );
        });

        it("should fail bid below current highest bid", async () => {
            const lowBid = web3.utils.toWei("1.5", "ether"); // 1.5 MONK
            await truffleAssert.reverts(
                bazaarInstance.placeBid(player1TokenIds[0], lowBid, {
                    from: player3,
                }),
                "Bid not higher than current bid"
            );
        });

        it("should return previous bid when outbid", async () => {
            const player2InitialBalance = await monkInstance.balanceOf(player2);
            const higherBid = web3.utils.toWei("3", "ether"); // 3 MONK

            await bazaarInstance.placeBid(player1TokenIds[0], higherBid, {
                from: player3,
            });

            const player2FinalBalance = await monkInstance.balanceOf(player2);
            const returnedAmount = player2FinalBalance.sub(player2InitialBalance);
            assert.equal(returnedAmount.toString(), web3.utils.toWei("2", "ether"), "Previous bid should be returned");
        });
    });

    describe("Buy Now", () => {
        it("should allow instant purchase at buy now price and correct comission handling", async () => {
            const listing = await bazaarInstance.getListingDetails(player1TokenIds[0]);
            const initialOwner = listing.seller;
            const buyNowPrice = listing.buyNowPrice;

            const initialSellerBalance = await monkInstance.balanceOf(initialOwner);

            await monkInstance.giveMonkApproval(bazaarInstance.address, buyNowPrice.toString(), {
                from: player2,
            });

            const result = await bazaarInstance.buyNow(player1TokenIds[0], {
                from: player2,
            });

            truffleAssert.eventEmitted(result, "MonkeySold", (ev) => {
                return (
                    ev.tokenId.toNumber() === player1TokenIds[0] &&
                    ev.seller === initialOwner &&
                    ev.buyer === player2 &&
                    ev.price.toString() === buyNowPrice.toString()
                );
            });

            const newOwner = await monkeysInstance.ownerOf(player1TokenIds[0]);
            assert.equal(newOwner, player2, "Ownership should transfer to buyer");

            const finalSellerBalance = await monkInstance.balanceOf(initialOwner);

            // Commission should be 2% (200 basis points)
            const expectedCommission = buyNowPrice.mul(web3.utils.toBN("200")).div(web3.utils.toBN("10000"));

            // Instead of looking at Bazaar balance change, verify the commission is accumulated in totalFees
            const bazaarFees = await bazaarInstance.totalFees();
            assert.equal(bazaarFees.toString(), expectedCommission.toString(), "Bazaar should receive 2% commission");

            const expectedSellerPayment = buyNowPrice.sub(expectedCommission);
            const actualSellerPayment = finalSellerBalance.sub(initialSellerBalance);

            assert.equal(
                actualSellerPayment.toString(),
                expectedSellerPayment.toString(),
                "Seller should receive price minus commission"
            );
        });
    });

    describe("Delisting", () => {
        it("should fail delisting when sender is not seller", async () => {
            await truffleAssert.reverts(
                bazaarInstance.delistMonkey(player1TokenIds[1], {from: player2}),
                "Not the seller"
            );
        });

        it("should fail delisting if auction has bids", async () => {
            await monkInstance.giveMonkApproval(bazaarInstance.address, web3.utils.toWei("2", "ether"), {
                from: player2,
            });
            await bazaarInstance.placeBid(player1TokenIds[1], web3.utils.toWei("2", "ether"), {from: player2});

            await truffleAssert.reverts(
                bazaarInstance.delistMonkey(player1TokenIds[1], {from: player1}),
                "Cannot delist: has bids"
            );
        });
    });

    describe("Auction", () => {
        before(async () => {
            await bazaarInstance.listMonkey(player1TokenIds[2], web3.utils.toWei("10", "ether"), START_BID_IN_WEI, {
                from: player1,
            });
        });

        it("should not allow bidding without sufficient MONK balance", async () => {
            await monkInstance.giveMonkApproval(bazaarInstance.address, web3.utils.toWei("5000", "ether"), {
                from: player2,
            });
            await truffleAssert.reverts(
                bazaarInstance.placeBid(player1TokenIds[1], web3.utils.toWei("5000", "ether"), {from: player2}),
                "Insufficient balance"
            );
        });

        it("should not allow seller to bid on own auction", async () => {
            const listingDetails = await bazaarInstance.getListingDetails(player1TokenIds[1]);
            await truffleAssert.reverts(
                bazaarInstance.placeBid(player1TokenIds[1], web3.utils.toWei("5", "ether"), {
                    from: listingDetails.seller,
                }),
                "Cannot bid on own listing"
            );
        });

        it("should not allow finalizing auction before end time", async () => {
            await truffleAssert.reverts(bazaarInstance.finalizeAuction(player1TokenIds[1]), "Auction still ongoing");
        });

        it("should return NFT to seller if no bids when auction ends", async () => {
            const listing = await bazaarInstance.getListingDetails(player1TokenIds[2]);
            const seller = listing.seller;

            // Fast forward time and mine block
            await new Promise((resolve, reject) => {
                web3.currentProvider.send(
                    {
                        jsonrpc: "2.0",
                        method: "evm_increaseTime",
                        params: [43200],
                        id: new Date().getTime(),
                    },
                    (err, result) => {
                        if (err) reject(err);
                        resolve(result);
                    }
                );
            });

            await new Promise((resolve, reject) => {
                web3.currentProvider.send(
                    {
                        jsonrpc: "2.0",
                        method: "evm_mine",
                        params: [],
                        id: new Date().getTime(),
                    },
                    (err, result) => {
                        if (err) reject(err);
                        resolve(result);
                    }
                );
            });

            await bazaarInstance.finalizeAuction(player1TokenIds[2]);
            const newOwner = await monkeysInstance.ownerOf(player1TokenIds[2]);
            assert.equal(newOwner, seller, "NFT should return to seller");
        });
    });

    describe("Fee Management", () => {
        it("should only allow owner to withdraw fees", async () => {
            await truffleAssert.reverts(
                bazaarInstance.withdrawFees({from: player1}),
                "Function accessible only by the owner !!"
            );
        });

        it("should correctly withdraw accumulated fees", async () => {
            const initialOwnerBalance = await monkInstance.balanceOf(owner);
            const initialFees = await bazaarInstance.totalFees();

            if (initialFees.toString() !== "0") {
                await bazaarInstance.withdrawFees({from: owner});
                const finalOwnerBalance = await monkInstance.balanceOf(owner);
                const finalFees = await bazaarInstance.totalFees();

                assert.equal(
                    finalOwnerBalance.sub(initialOwnerBalance).toString(),
                    initialFees.toString(),
                    "Owner should receive all accumulated fees"
                );
                assert.equal(finalFees.toString(), "0", "Total fees should be reset to 0");
            }
        });
    });

    describe("Edge Cases", () => {
        it("should fail buying unlisted monkey", async () => {
            await truffleAssert.reverts(bazaarInstance.buyNow(9999), "Not listed");
        });

        it("should fail bidding on unlisted monkey", async () => {
            await truffleAssert.reverts(
                bazaarInstance.placeBid(9999, web3.utils.toWei("1", "ether")),
                "Not an active auction"
            );
        });

        it("should fail listing with start bid higher than buy now", async () => {
            await truffleAssert.reverts(
                bazaarInstance.listMonkey(
                    player1TokenIds[2],
                    web3.utils.toWei("10", "ether"),
                    web3.utils.toWei("20", "ether"),
                    {from: player1}
                ),
                "Starting bid must be lower than buy now price"
            );
        });

        it("should fail listing with zero buy now price", async () => {
            await truffleAssert.reverts(
                bazaarInstance.listMonkey(player1TokenIds[2], 0, 0, {from: player1}),
                "Buy now price must be greater than 0"
            );
        });
    });
});
