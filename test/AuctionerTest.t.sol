// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Auctioner} from "../src/Auctioner.sol";

contract AuctionerTest is Test {
    Auctioner public auctioner;

    function setUp() public {
        auctioner = new Auctioner("Auctioner", "AUC");
    }
}
