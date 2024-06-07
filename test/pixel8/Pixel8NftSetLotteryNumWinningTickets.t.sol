// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { Pixel8NftTestBase } from "./Pixel8NftTestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "src/LibErrors.sol";


contract Pixel8NftSetLotteryNumWinningTickets is Pixel8NftTestBase {
  function test_SetLotteryNumWinningTickets_WhenOwner_Succeeds() public {
    vm.prank(owner1);
    pixel8.setLotteryNumWinningTickets(1);
    assertEq(pixel8.getLottery().numWinningTickets, 1);
  }

  function test_SetLotteryNumWinningTickets_WhenNotOwner_Fails() public {
    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, minter1));
    pixel8.setLotteryNumWinningTickets(1);

    address random = address(0x8876);
    vm.prank(random);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
    pixel8.setLotteryNumWinningTickets(1);
  }

  function test_SetLotteryNumWinningTickets_WhenAlreadySet_Fails() public {
    vm.prank(owner1);
    pixel8.setLotteryNumWinningTickets(1);

    vm.prank(owner1);
    vm.expectRevert(LibErrors.LotteryNumWinningTicketsAlreadySet.selector);
    pixel8.setLotteryNumWinningTickets(1);
  }

  function test_SetLotteryNumWinningTickets_WhenInvalidNumber_Fails() public {
    vm.prank(owner1);
    vm.expectRevert(LibErrors.LotteryInvalidNumWinningTickets.selector);
    pixel8.setLotteryNumWinningTickets(0);
  }
}
