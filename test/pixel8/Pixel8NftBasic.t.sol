// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { Pixel8NftTestBase } from "./Pixel8NftTestBase.sol";

contract Pixel8NftBasic is Pixel8NftTestBase {
  function test_DefaultConfig() public {
    assertEq(pixel8.name(), "Pixel8", "name");
    assertEq(pixel8.symbol(), "PIXEL8", "symbol");
    assertEq(pixel8.owner(), owner1, "owner");
    assertEq(pixel8.minter(), minter1, "minter");
    assertEq(pixel8.pool(), address(0), "pool");
    assertEq(pixel8.defaultImage(), "img", "defaultImg");

    Pixel8.DevRoyalties memory devRoyalties = pixel8.getDevRoyalties();
    assertEq(devRoyalties.feeBips, 1000, "devRoyalties.feeBips");
    assertEq(devRoyalties.receiver, owner1, "devRoyalties.receiver");

    Pixel8.Lottery memory lottery = pixel8.getLottery();
    assertEq(lottery.feeBips, 1000, "lottery.feeBips");
    assertEq(lottery.deadline, block.timestamp + 10, "lottery.deadline");
    assertEq(lottery.tileRevealThreshold, 10, "lottery.tileRevealThreshold");
    assertEq(lottery.drawn, false, "lottery.drawn");
    assertEq(lottery.drawnPot, 0, "lottery.drawnPot");
    assertEq(lottery.numWinningTickets, 0, "lottery.numWinningTickets");
    assertEq(address(lottery.nft), address(0), "lottery.ticketNFT");

    assertEq(pixel8.getLotteryPot(), 0, "getLotteryPotSoFar");

    assertEq(pixel8.totalSupply(), 0, "totalSupply");
    (address r1, uint r2) = pixel8.royaltyInfo(0, 100);
    assertEq(r1, pixel8_addr, "royaltyInfo.receiver");
    assertEq(r2, 20, "royaltyInfo.fee");

    (address rec, uint fee) = pixel8.getRoyaltyInfo();
    assertEq(rec, pixel8_addr, "getRoyaltyInfo.receiver");
    assertEq(fee, 2000, "getRoyaltyInfo.fee");
  }

  function test_ClaimGasRefunds_WhenOwner() public {
    vm.prank(owner1);
    pixel8.claimGasRefunds();
  }

  function test_ClaimGasRefunds_WhenNotOwner() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, wallet1));
    pixel8.claimGasRefunds();
  }
}
