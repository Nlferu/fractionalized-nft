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

contract Auctioner is ERC20, Ownable, ERC20Permit, ERC20Votes, ReentrancyGuard, IERC721Receiver {
    /// @dev Errors
    error Auctioner__AuctionUnscheduled();
    error Auctioner__AuctionNotOpened();
    error Auctioner__InsufficientFractions();

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
        FINISHED,
        ARCHIVED
    }

    /// @dev Structs
    struct Auction {
        address associatedCoin; // Address of associated erc20 contract
        IERC721 collection; // Address of nft that we want to fractionalize
        uint tokenId; // TokenId of NFT that we want to fractionalize
        uint closeTs; // Timestamp - auction close
        uint openTs; // Timestamp - auction open
        uint available; // Timestamp - amount of nft fractions left for sale
        uint total; // Timestamp - total of nft fractions
        uint price; // Price of one nft fraction
        address[] tokenOwners; // NFT owners array
        AuctionState auctionState; // Auction status
    }

    /// @dev Mappings
    mapping(uint tokenId => Auction map) private s_auctions;

    /// @dev Events
    event AuctionCreated(uint indexed id, address collection, uint tokenId, uint indexed nftFractionsAmount, uint indexed price);

    /// @dev Constructor
    constructor(string memory name, string memory symbol, address payable broker) Ownable(msg.sender) ERC20(name, symbol) ERC20Permit(name) {
        i_broker = broker;
    }

    // Owner of nft use this to transfer NFT to our contract
    function schedule(address _collection, uint _tokenId, uint _nftFractionsAmount, uint _price) external onlyOwner {
        Auction storage auction = s_auctions[s_totalAuctions];

        Fractionalizer associated_erc20 = new Fractionalizer("xxx", "sad");
        auction.associatedCoin = address(associated_erc20);

        auction.collection = IERC721(_collection);
        auction.collection.safeTransferFrom(msg.sender, address(this), _tokenId);
        auction.tokenId = _tokenId;

        auction.total = _nftFractionsAmount;
        auction.available = _nftFractionsAmount;
        auction.price = _price;

        auction.auctionState = AuctionState.SCHEDULED;

        emit AuctionCreated(s_totalAuctions, _collection, _tokenId, _nftFractionsAmount, _price);

        s_totalAuctions += 1;
    }

    function open(uint _auction) external onlyOwner {
        Auction storage auction = s_auctions[_auction];
        if (auction.auctionState != AuctionState.SCHEDULED) revert Auctioner__AuctionUnscheduled();

        auction.openTs = block.timestamp;
        auction.closeTs = block.timestamp + 30 days;
        auction.auctionState = AuctionState.OPEN;
    }

    function buy(uint _auction, uint _no /*number of pieces to be minted (bought)*/) external nonReentrant {
        Auction storage auction = s_auctions[_auction];
        if (auction.auctionState != AuctionState.OPEN) revert Auctioner__AuctionNotOpened();
        if (auction.available < _no || _no == 0) revert Auctioner__InsufficientFractions();

        auction.available -= _no;
        auction.tokenOwners.push(msg.sender);

        // ERC20 coins factory -> TO BE FIXED
        _mint(msg.sender, _no);

        // ERC20
        //_mint(msg.sender, _amount);
    }

    function _update(address from, address to, uint value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint) {
        return super.nonces(owner);
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
