// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Overlap with ERC721
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Auction is ERC721, ERC721Enumerable, Ownable, EIP712, ERC721Votes, ReentrancyGuard, IERC721Receiver {
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

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) EIP712(name, symbol) {}

    //...
    //code omitted
    //...
    function buy(uint256 no /*number of pieces to be minted (bought)*/) public view {
        total - no;
    }

    //...
    //code omitted
    //...

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable, ERC721Votes) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable, ERC721Votes) {
        super._increaseBalance(account, value);
    }

    function onERC721Received(address /* operator */, address /* from */, uint256 tokenId, bytes memory /* data */) public override returns (bytes4) {
        receivedTokens.push(tokenId);

        return this.onERC721Received.selector;
    }
}

// Założenia:
// Napisac metodę buy(), przyjmuje ona tylko jeden argument "no" reprezentujący ilość kupowanych pieces NFT (pNFT) po cenie przechowywanej w zmiennej price.
// Aby można było kupić, aukcja musi być w statusie Open, po openTs, a przed closeTs.
// W przypadku próby kupienia bez spełnienia warunków powinnien być zwracany odpowiedni komunikat do wywołującego.
// Podczas zakupu pNFT mają być mintowane oraz mieć od razu zdelegowane uprawienie do głosowania pNFT na kupującego.
// W przypadku zmiany zmiennej available oraz status, aukcja powinna emitować odpowiednie informacje na blockchain.
// Zakładamy, że zmienne są odpowiednio zainicjalizowane.
// Po wykupieniu wszystkich dostępnych pNFT, status musi się zmienić na Closed (pozytywnie zakończona aukcja), oraz środki powinny być przetransferowane na adres Brokera.
// Przy próbie zakupienia po closeTs, ale gdy pNFT nie są wszystkie wyprzedane, status musi się zmienić na Failed (negatywnie zakończona aukcja).
// Po zmianie status na Failed środki powinny być przetransferowane z powrotem proporcjonalnie do kupujących.
