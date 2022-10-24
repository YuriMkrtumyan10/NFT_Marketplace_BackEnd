// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error ItemNotForSale(address nftAddress, uint256 tokenId);
error NotListed(address nftAddress, uint256 tokenId);
error AlreadyListed(address nftAddress, uint256 tokenId);
error NoProceeds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();

contract NftMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        address seller;
    }

    // IsNotOwner Modifier - Nft Owner can't buy his/her NFT
    // Modifies buyItem function
    // Owner should only list, cancel listing or update listing
    /* modifier isNotOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender == owner) {
            revert IsNotOwner();
        }
                            _;
    } */

    /////////////////////
    //    Mappings     //
    /////////////////////

    // NFT Contract Address -> NFT TokenID -> Listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    // Seller Address -> Amount earned
    mapping(address => uint256) private s_proceeds;

    /////////////////////
    //     Events      //
    /////////////////////

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(address indexed buyer, address indexed nftAddress, uint256 indexed tokenId);

    event ItemUpdated(
        address indexed owner,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 newPrice
    );

    /////////////////////
    //    Modifiers    //
    /////////////////////

    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NotListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwnerNft(
        address nftaddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftaddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NotOwner();
        }
        _;
    }

    /////////////////////
    // Main Functions  //
    /////////////////////

    /*
     * @notice Method for listing NFT
     * @param _nftAddress - the address of NFT
     * @param _tokenId - the token id of NFT
     * @param _price - sale price of the item
     */
    function listItem(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    )
        external
        notListed(_nftAddress, _tokenId, msg.sender)
        isOwnerNft(_nftAddress, _tokenId, msg.sender)
    {
        if (_price <= 0) {
            revert PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(_nftAddress);

        if (nft.getApproved(_tokenId) != address(this)) {
            revert NotApprovedForMarketplace();
        }

        s_listings[_nftAddress][_tokenId] = Listing(_price, msg.sender);
        emit ItemListed(msg.sender, _nftAddress, _tokenId, _price);
    }

    /*
     * @notice Method for buying listing
     * @notice The owner of an NFT could unapprove the marketplace, which would cause this function to fail
     * @param _nftAddress - the address of NFT
     * @param _tokenId - the token id of NFT
     */
    function buyItem(address _nftAddress, uint256 _tokenId)
        external
        payable
        isListed(_nftAddress, _tokenId)
        nonReentrant
    {
        Listing memory listedItem = s_listings[_nftAddress][_tokenId];
        if (msg.value < listedItem.price) {
            revert PriceNotMet(_nftAddress, _tokenId, listedItem.price);
        }

        //when someone buy an NFT update the proceeds
        s_proceeds[listedItem.seller] += msg.value;
        delete (s_listings[_nftAddress][_tokenId]);

        IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _tokenId);
        emit ItemBought(msg.sender, _nftAddress, _tokenId, listedItem.price);
    }

    /*
     * @notice Method for canceling listing
     * @param _nftAddress - the address of NFT
     * @param _tokenId - the token id of NFT
     */
    function cancelListing(address _nftAddress, uint256 _tokenId)
        external
        isOwnerNft(_nftAddress, _tokenId, msg.sender)
        isListed(_nftAddress, _tokenId)
    {
        delete (s_listings[_nftAddress][_tokenId]);
        emit ItemCanceled(msg.sender, _nftAddress, _tokenId);
    }

    /*
     * @notice Method for updating the price of a listing
     * @param _nftAddress - the address of NFT
     * @param _tokenId - the token id of NFT
     * @param _newPrice - the new price of NFT
     */
    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newPrice
    ) external isOwnerNft(_nftAddress, _tokenId, msg.sender) isListed(_nftAddress, _tokenId) {
        if (_newPrice <= 0) {
            revert PriceMustBeAboveZero();
        }

        s_listings[_nftAddress][_tokenId].price = _newPrice;
        emit ItemUpdated(msg.sender, _nftAddress, _tokenId, _newPrice);
    }

    /*
     * @notice Method for withdrawing the proceeds
     * @dev transfering by low-level function
     */
    function withdrawProceeds() external {
        uint256 proceedsToWithdraw = s_proceeds[msg.sender];

        if (proceedsToWithdraw <= 0) {
            revert NoProceeds();
        }

        s_proceeds[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: proceedsToWithdraw}("");
        require(success, "Transfer failed");
    }

    /////////////////////
    //  Getters Funcs  //
    /////////////////////

    function getListing(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (Listing memory)
    {
        return s_listings[_nftAddress][_tokenId];
    }

    function getProceeds(address _seller) external view returns (uint256) {
        return s_proceeds[_seller];
    }
}
