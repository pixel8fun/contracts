// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Pixel8TestBase} from "./Pixel8TestBase.sol";
import { console2 as c } from "forge-std/console2.sol";
import { Vm } from "forge-std/Vm.sol";
import { LibErrors } from "../../src/LibErrors.sol";


contract Pixel8TradeRecordingTest is Pixel8TestBase {
    function setUp() virtual override public {
      super.setUp();

      vm.prank(owner1);
      pixel8.setPool(pool1);  
    }


    function testRecordTrade_OnlyPoolCanRecord() public {
        vm.prank(wallet1);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, wallet1));
        pixel8.recordTrade(wallet1, 1 ether, true, 1);
    }

    function testRecordTrade_EmitsEvent() public {
        vm.recordLogs();
        vm.startPrank(pool1);
        
        pixel8.recordTrade(wallet1, 1 ether, true, 1);
        pixel8.recordTrade(wallet1, 2 ether, false, 2);
        
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2, "Should emit two events");
        assertEq(entries[0].topics[0], keccak256("TradeRecorded(address,uint256,bool,uint256)"), "Wrong event signature for first trade");
        assertEq(entries[1].topics[0], keccak256("TradeRecorded(address,uint256,bool,uint256)"), "Wrong event signature for second trade");
    }

    function testRecordTrade_UpdatesVolume() public {
        vm.startPrank(pool1);
        
        pixel8.recordTrade(wallet1, 1 ether, true, 1);
        assertEq(pixel8.tradingVolume(wallet1), 1 ether);
        
        pixel8.recordTrade(wallet1, 2 ether, false, 1);
        assertEq(pixel8.tradingVolume(wallet1), 3 ether);
        
        pixel8.recordTrade(wallet1, 3 ether, true, 1);
        assertEq(pixel8.tradingVolume(wallet1), 6 ether);
        
        vm.stopPrank();
    }
} 