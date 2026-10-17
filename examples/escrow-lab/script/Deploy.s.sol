// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {TimedEscrow} from "../src/TimedEscrow.sol";

contract Deploy is Script {
    function run() external returns (TimedEscrow escrow) {
        address buyer = vm.envAddress("BUYER");
        address payable seller = payable(vm.envAddress("SELLER"));
        uint256 price = vm.envUint("PRICE_WEI");
        uint256 deadline = block.timestamp + 1 days;
        vm.startBroadcast();
        escrow = new TimedEscrow(buyer, seller, price, deadline);
        vm.stopBroadcast();
    }
}
