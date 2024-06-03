// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Fractionalizer} from "./Fractionalizer.sol";

contract Auctioner is Ownable, ReentrancyGuard, IERC721Receiver {
    /// @dev Libraries
    using Strings for uint256;
    using Strings for address;

    /// @dev Errors
    error Auctioner__AuctionUnscheduled();
    error Auctioner__AuctionNotOpened();
    error Auctioner__InsufficientFractions();
    error Auctioner__NotEnoughETH();
    error Auctioner__TransferFailed();

    /// @dev Variables
    uint private s_totalAuctions;
    address payable immutable i_broker;

    /// @dev Arrays
    uint[] private s_receivedTokens;

    /// @dev Enums
    enum AuctionState {
        UNSCHEDULED,
        SCHEDULED,
        OPEN, // auction ready to get orders for nft fractions
        CLOSED, // auction finished positively - all nft fractions bought
        FAILED, // auction finished negatively - not all nft fractions bought
        FINISHED, // UNUSED
        ARCHIVED
    }

    /// @dev Structs
    struct Auction {
        address associatedCoin; // Address of associated erc20 contract
        IERC721 collection; // Address of nft that we want to fractionalize
        uint tokenId; // TokenId of NFT that we want to fractionalize
        uint closeTs; // Timestamp - auction close -> CAUTION we can safely remove openTs as time left will be sufficient
        uint openTs; // Timestamp - auction open
        uint available; // Amount of nft fractions left for sale
        uint total; // Total of nft fractions
        uint price; // Price of one nft fraction
        uint payments; // Total ETH gathered
        address[] tokenOwners; // NFT owners array
        mapping(address => uint) buyerToFunds; // It maps auction id to buyer address to funds he spent on purchase
        AuctionState auctionState; // Auction status
    }

    /// @dev Mappings
    mapping(uint tokenId => Auction map) private s_auctions;

    /// @dev Events
    event AuctionCreated(uint indexed id, address collection, uint tokenId, uint indexed nftFractionsAmount, uint indexed price);
    event Purchase(uint auction, address buyer, uint amount, uint available);
    event FundsTransferredToBroker(uint indexed amount);
    event AuctionStateChange(uint indexed auction, AuctionState indexed state);
    event AuctionOpened(uint indexed openTime, uint indexed closeTime);
    event AuctionRefund(address indexed buyer, uint indexed amount);

    /// @dev Constructor
    constructor(address payable broker) Ownable(msg.sender) {
        i_broker = broker;
    }

    // Owner of nft use this to transfer NFT to our contract
    function schedule(address _collection, uint _tokenId, uint _nftFractionsAmount, uint _price) external onlyOwner {
        Auction storage auction = s_auctions[s_totalAuctions];

        string memory collection = Strings.toHexString(_collection);
        string memory token = Strings.toString(_tokenId);

        Fractionalizer associated_erc20 = new Fractionalizer(collection, token);
        auction.associatedCoin = address(associated_erc20);

        auction.collection = IERC721(_collection);
        auction.collection.safeTransferFrom(msg.sender, address(this), _tokenId);
        auction.tokenId = _tokenId;

        auction.total = _nftFractionsAmount;
        auction.available = _nftFractionsAmount;
        auction.price = _price;

        emit AuctionCreated(s_totalAuctions, _collection, _tokenId, _nftFractionsAmount, _price);

        auction.auctionState = AuctionState.SCHEDULED;

        emit AuctionStateChange(s_totalAuctions, auction.auctionState);

        s_totalAuctions += 1;
    }

    // We as contract owner are allowed to open purchase for specific NFT
    function open(uint _auction) external onlyOwner {
        Auction storage auction = s_auctions[_auction];
        if (auction.auctionState != AuctionState.SCHEDULED) revert Auctioner__AuctionUnscheduled();

        auction.openTs = block.timestamp;
        auction.closeTs = block.timestamp + 30 days;

        emit AuctionOpened(auction.openTs, auction.closeTs);

        auction.auctionState = AuctionState.OPEN;

        emit AuctionStateChange(_auction, auction.auctionState);
    }

    // Allows user to buy fraction of NFT
    function buy(uint _auction, uint _no) external payable nonReentrant {
        Auction storage auction = s_auctions[_auction];
        if (auction.auctionState != AuctionState.OPEN) revert Auctioner__AuctionNotOpened();
        if (auction.available < _no || _no == 0) revert Auctioner__InsufficientFractions();
        if (msg.value < (_no * auction.price)) revert Auctioner__NotEnoughETH();

        // Updating Auction struct
        auction.available -= _no;
        auction.payments += msg.value;
        if (auction.buyerToFunds[msg.sender] == 0) auction.tokenOwners.push(msg.sender);
        auction.buyerToFunds[msg.sender] += msg.value;

        // Mint the pNFTs to the buyer
        Fractionalizer(auction.associatedCoin).mint(msg.sender, _no);

        // Automatically delegate votes to the buyer
        Fractionalizer(auction.associatedCoin).delegate(msg.sender);

        emit Purchase(_auction, msg.sender, _no, auction.available);

        if (auction.available == 0) {
            auction.auctionState = AuctionState.CLOSED;

            emit AuctionStateChange(_auction, auction.auctionState);

            // Transfer funds to the broker
            (bool success, ) = i_broker.call{value: auction.payments}("");
            if (!success) revert Auctioner__TransferFailed();

            emit FundsTransferredToBroker(auction.payments);
        } else if (block.timestamp > auction.closeTs) {
            auction.auctionState = AuctionState.FAILED;

            emit AuctionStateChange(_auction, auction.auctionState);

            // UNSAFE METHOD
            refundBuyers(_auction);
        }
    }

    // Handles refunds if auction fails to sell all fractions in given time
    function refundBuyers(uint _auction) internal {
        Auction storage auction = s_auctions[_auction];

        for (uint i = 0; i < auction.tokenOwners.length; i++) {
            address buyer = auction.tokenOwners[i];
            uint amount = auction.buyerToFunds[buyer];

            if (amount > 0) {
                // Burn the pNFTs from the buyer
                uint256 tokenBalance = Fractionalizer(auction.associatedCoin).balanceOf(buyer);
                Fractionalizer(auction.associatedCoin).burnFrom(buyer, tokenBalance);

                auction.buyerToFunds[buyer] = 0; // Prevent re-entrancy

                // Refund the buyer
                (bool success, ) = buyer.call{value: amount}("");
                if (!success) revert Auctioner__TransferFailed();

                emit AuctionRefund(buyer, amount);
            }
        }

        auction.auctionState = AuctionState.ARCHIVED;

        emit AuctionStateChange(_auction, auction.auctionState);
    }

    function onERC721Received(address /* operator */, address /* from */, uint _tokenId, bytes memory /* data */) public override returns (bytes4) {
        s_receivedTokens.push(_tokenId);

        return this.onERC721Received.selector;
    }
}

// Założenia:
// Napisac metodę buy(), przyjmuje ona tylko jeden argument "no" reprezentujący ilość kupowanych pieces NFT (pNFT) po cenie przechowywanej w zmiennej price.
// Aby można było kupić, aukcja musi być w statusie Open, po openTs, a przed closeTs.
// W przypadku próby kupienia bez spełnienia warunków powinien być zwracany odpowiedni komunikat do wywołującego.
// Podczas zakupu pNFT mają być mintowane oraz mieć od razu zdelegowane uprawienie do głosowania pNFT na kupującego.
// W przypadku zmiany zmiennej available oraz status, aukcja powinna emitować odpowiednie informacje na blockchain.
// Zakładamy, że zmienne są odpowiednio zainicjalizowane.
// Po wykupieniu wszystkich dostępnych pNFT, status musi się zmienić na Closed (pozytywnie zakończona aukcja), oraz środki powinny być przetransferowane na adres Brokera.
// Przy próbie zakupienia po closeTs, ale gdy pNFT nie są wszystkie wyprzedane, status musi się zmienić na Failed (negatywnie zakończona aukcja).
// Po zmianie status na Failed środki powinny być przetransferowane z powrotem proporcjonalnie do kupujących.
