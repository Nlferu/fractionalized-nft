// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Auctioner} from "../src/Auctioner.sol";

contract AuctionerTest is Test {
    Auctioner public auctioner;
    address payable broker;

    function setUp() public {
        auctioner = new Auctioner(broker);
    }
}
