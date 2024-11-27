const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("NFT Marketplace", function () {
    let NFTMarket;
    let nftMarket;
    let listingPrice;
    let contractOwner;
    let buyerAddress;
    let nftMarketAddress;

    const auctionPrice = ethers.utils.parseEther("100","ether");

    beforeEach(async function () {
        NFTMarket = await ethers.getContractFactory("NFTMarket");
        nftMarket = await NFTMarket.deploy();
        await nftMarket.waitForDeployment();
        nftMarketAddress = await nftMarket.address;
        [contractOwner,buyerAddress] = await ethers.getSigners();
        listingPrice = await nftMarket.getListingPrice().toString();    
    });
    const mintAndListNFT = async (tokenURI, auctionPrice) => {
        const transaction = await nftMarket.createToken(tokenURI, auctionPrice,{value:listingPrice});
        const receipt = await transaction.wait();
        const tokenID = receipt.events[0].args.tokenId;
        return tokenID;
    }

    describe("Mint and list a new NFT token", function(){
        const tokenURI = "https://example.com/nft/1";
        it("Should revert if price is zero", async ()=>{
            await expect(mintAndListNFT(tokenURI,0)).to.be.revertedWith("Price must be greater than zero");
        });
        it("Should revert if listing price is not correct", async ()=>{
            await expect(nftMarket.createToken(tokenURI, auctionPrice,{value:0})).to.be.revertedWith("Price must be equal to listing price");
        })
    });
})