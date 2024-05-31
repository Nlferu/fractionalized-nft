// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {ERC721Enumerable, ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions";
import {ERC721, IERC721, IERC721Receiver} from "@openzeppelin/contracts/token/ERC721";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Auction is
    ERC721,
    ERC721Enumerable,
    ERC721Votes,
    IERC721Receiver,
    ReentrancyGuard
{
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

    //...
    //code omitted
    //...
    function buy(uint256 no /*number of pieces to be minted (bought)*/) public {
        //....
        //Your code here
        //....
    }
    //...
    //code omitted
    //...
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
