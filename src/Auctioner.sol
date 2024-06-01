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

contract Auctioner is ERC20, Ownable, ERC20Permit, ERC20Votes, ReentrancyGuard, IERC721Receiver {
    // Address of nft that we want to fractionalize
    IERC721 public collection;
    // TokenId of NFT that we want to fractionalize
    uint256 public tokenId;

    // Owner of nft use this to transfer NFT to our contract
    function initialize(address _collection, uint256 _tokenId, uint256 _amount) external onlyOwner {
        collection = IERC721(_collection);
        collection.safeTransferFrom(msg.sender, address(this), _tokenId);
        tokenId = _tokenId;

        // ERC20
        _mint(msg.sender, _amount);
    }

    //Zmienne:
    //...
    //Available statuses:
    //Scheduled = 1
    //Open = 2 - aukcja gotowa na zakupy pNFT
    //Closed = 3 - aukcja zakończona pozytywnie - wszystki pNFT wykupione
    //Failed = 4 - aukcja zakończona negatywnie - nie wszystkie pNFT wykupione
    //Finished = 5
    //Archived = 6
    //Only in status Open pieces can be minted (bought)
    uint256 public status = 1;
    //...
    uint256 public closeTs; // - timestamp - zamknięcie aukcji
    uint256 public openTs; // - timestamp - otwarcie aukcji
    uint256 public available; // - timestamp - pozostała ilość pNFT
    uint256 public total; // - timestamp - całkowita ilość pNFT
    uint256 public price; // - cena pojedynczego pNFT
    address[] tokenOwners; // - lista właścicieli
    address payable public broker; // - adres brokera

    uint256[] private receivedTokens;

    constructor(string memory name, string memory symbol) Ownable(msg.sender) ERC20(name, symbol) ERC20Permit(name) {}

    //...
    //code omitted
    //...
    function buy(uint256 no /*number of pieces to be minted (bought)*/) public view {
        total - no;
    }

    //...
    //code omitted
    //...

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function onERC721Received(address /* operator */, address /* from */, uint256 _tokenId, bytes memory /* data */) public override returns (bytes4) {
        receivedTokens.push(_tokenId);

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
