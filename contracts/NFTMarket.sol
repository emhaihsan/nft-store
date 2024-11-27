// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Import OpenZeppelin contracts for ERC721 token standard
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/**
 * @title NFTMarket
 * @dev This contract implements an NFT marketplace, allowing users to create, buy, and sell NFTs.
 * It extends ERC721URIStorage to support metadata for each token.
 */
contract NFTMarket is ERC721URIStorage {
    // State variables

    /// @dev Tracks the total number of tokens minted
    uint256 private _tokenIds;

    /// @dev Counts the number of items sold in the marketplace
    uint256 private _itemsSold;

    /// @dev Fee required to list an NFT in the marketplace
    uint256 public listingPrice = 0.001 ether;

    /// @dev Address of the contract owner, who can update the listing price
    address payable public owner;

    /// @dev Maps token IDs to their respective market items
    mapping(uint256 => MarketItem) private idToMarketItem;

    /**
     * @dev Struct to represent an item in the marketplace
     * @param tokenId Unique identifier for the NFT
     * @param seller Address of the current seller
     * @param owner Address of the current owner
     * @param price Price set by the seller
     * @param sold Boolean indicating if the item has been sold
     */
    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    /**
     * @dev Event emitted when a new market item is created
     * @param id Token ID of the new item
     * @param seller Address of the seller
     * @param owner Address of the owner (initially the contract)
     * @param price Initial listing price
     * @param sold Initial sold status (always false for new items)
     */
    event MarketItemCreated(
        uint256 id,
        address payable seller,
        address payable owner,
        uint256 price,
        bool sold
    );

    /**
     * @dev Constructor initializes the ERC721 token with a name and symbol
     * Sets the contract deployer as the owner
     */
    constructor() ERC721("IndoNFTMarket", "INM") {
        owner = payable(msg.sender);
    }

    /**
     * @dev Retrieves the current listing price
     * @return The current listing price in wei
     */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /**
     * @dev Allows the owner to update the listing price
     * @param _listingPrice New listing price in wei
     */
    function updateListingPrice(uint256 _listingPrice) public payable {
        require(
            msg.sender == owner,
            "Only the owner can update the listing price"
        );
        listingPrice = _listingPrice;
    }

    /**
     * @dev Creates a new market item for an existing NFT
     * @param tokenId The ID of the token to be listed
     * @param price The price at which the item is listed
     */
    function createMarketItem(uint256 tokenId, uint256 price) public payable {
        require(price > 0, "Price must be greater than zero");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        // Create a new market item and store it in the mapping
        idToMarketItem[tokenId] = MarketItem({
            tokenId: tokenId,
            seller: payable(msg.sender),
            owner: payable(address(this)),
            price: price,
            sold: false
        });

        // Transfer the token from the seller to the contract
        _transfer(msg.sender, address(this), tokenId);

        // Emit an event to log the creation of the market item
        emit MarketItemCreated(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );
    }

    /**
     * @dev Creates a new token and lists it on the marketplace
     * @param tokenURI The URI containing metadata of the token
     * @param price The price at which the token will be listed
     * @return The ID of the newly created token
     */
    function createToken(
        string memory tokenURI,
        uint256 price
    ) public payable returns (uint256) {
        _tokenIds++; // Increment the token ID counter
        uint256 newTokenId = _tokenIds; // Get the new token ID
        _mint(msg.sender, newTokenId); // Mint the new token to the sender's address
        _setTokenURI(newTokenId, tokenURI); // Set the token's metadata URI
        createMarketItem(newTokenId, price); // List the token on the marketplace
        return newTokenId; // Return the new token's ID
    }

    /**
     * @dev Creates a market sale for a specific NFT.
     * @param tokenId The ID of the token to be sold.
     * @notice This function must be called with the correct amount of Ether to purchase the NFT.
     */
    function createMarketSale(uint256 tokenId) public payable {
        uint price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;

        // Ensure the sent value matches the NFT's price
        require(msg.value == price, "Price must be equal to listing price");

        // Update the NFT's ownership and status
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].seller = payable(address(0)); // Reset seller
        _itemsSold++;

        // Transfer NFT ownership
        _transfer(address(this), msg.sender, tokenId);

        // Distribute funds: listing fee to contract owner, sale price to seller
        payable(owner).transfer(listingPrice);
        payable(seller).transfer(msg.value);
    }

    /**
     * @dev Fetches all unsold market items
     * @return An array of MarketItem structs representing unsold items
     */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds;
        uint256 unsoldItemCount = _tokenIds - _itemsSold;
        uint256 currentIndex = 0;

        // Create an array to store unsold items
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        // Iterate through all items
        for (uint256 i = 0; i < itemCount; i++) {
            uint256 currentId = i + 1;
            // Check if the item is unsold (owned by the contract)
            if (idToMarketItem[currentId].owner == address(this)) {
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex++;
            }
        }
        return items;
    }

    /**
     * @dev Fetches all NFTs owned by the caller
     * @return An array of MarketItem structs representing the caller's NFTs
     */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // Count how many NFTs are owned by the caller
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount++;
            }
        }

        // Initialize an array to store the caller's NFTs
        MarketItem[] memory items = new MarketItem[](itemCount);

        // Populate the array with the caller's NFTs
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex++;
            }
        }
        return items;
    }

    /**
     * @dev Fetches the list of market items created by the caller
     * @return An array of MarketItem structs representing the items listed by the caller
     */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds; // Total number of tokens minted
        uint256 itemCount = 0; // Counter for the number of items listed by the caller
        uint256 currentIndex = 0; // Index for populating the items array

        // Count the number of items listed by the caller
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount++;
            }
        }

        // Create an array to hold the caller's listed items
        MarketItem[] memory items = new MarketItem[](itemCount);

        // Populate the array with the caller's listed items
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1; // Token ID is 1-based
                MarketItem storage currentItem = idToMarketItem[currentId]; // Retrieve the market item
                items[currentIndex] = currentItem; // Add item to the array
                currentIndex++;
            }
        }
        return items; // Return the array of market items
    }

    /**
     * @dev Allows the owner of an NFT to resell it on the marketplace.
     * @param tokenId The ID of the token to be resold.
     * @param newPrice The new price for which the token will be listed.
     * @notice The caller must be the owner of the token and must provide the listing price.
     */
    function resellToken(uint256 tokenId, uint256 newPrice) public payable {
        require(
            idToMarketItem[tokenId].owner == msg.sender,
            "Only item owner can perform this operation"
        );
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        // Update market item details
        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = newPrice;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));

        _itemsSold--; // Decrement the count of sold items

        // Transfer the token back to the contract
        _transfer(msg.sender, address(this), tokenId);
    }

    /**
     * @dev Cancels the listing of a market item by the seller.
     * @param tokenId The ID of the token whose listing is to be canceled.
     * @notice The caller must be the seller of the item, and the item must not have been sold.
     */
    function cancelItemListing(uint256 tokenId) public {
        require(
            idToMarketItem[tokenId].seller == msg.sender,
            "Only item seller can perform this operation"
        );
        require(
            idToMarketItem[tokenId].sold == false,
            "Item has already been sold"
        );

        // Update market item details to reflect cancellation
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].seller = payable(address(0));
        idToMarketItem[tokenId].sold = false;

        _itemsSold--; // Decrement the count of sold items

        // Refund the listing price to the contract owner
        payable(owner).transfer(listingPrice);

        // Transfer the token back to the original seller
        _transfer(address(this), msg.sender, tokenId);
    }
}
