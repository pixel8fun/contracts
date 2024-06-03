// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { PuzzArt } from "src/PuzzArt.sol";
import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";

contract PuzzArtNftBasic is PuzzArtNftTestBase {
  function test_DefaultConfig() public {
    assertEq(puzzArt.name(), "PuzzArt", "name");
    assertEq(puzzArt.symbol(), "PUZZART", "symbol");
    assertEq(puzzArt.owner(), owner1, "owner");
    assertEq(puzzArt.minter(), minter1, "minter");
    assertEq(puzzArt.pool(), address(0), "pool");
    assertEq(puzzArt.defaultImage(), "img", "defaultImg");

    PuzzArt.DevRoyalties memory devRoyalties = puzzArt.getDevRoyalties();
    assertEq(devRoyalties.feeBips, 1000, "devRoyalties.feeBips");
    assertEq(devRoyalties.receiver, owner1, "devRoyalties.receiver");

    PuzzArt.Lottery memory lottery = puzzArt.getLottery();
    assertEq(lottery.feeBips, 1000, "lottery.feeBips");
    assertEq(lottery.deadline, block.timestamp + 10, "lottery.deadline");
    assertEq(lottery.tileRevealThreshold, 10, "lottery.tileRevealThreshold");
    assertEq(lottery.drawn, false, "lottery.drawn");
    assertEq(lottery.drawnPot, 0, "lottery.drawnPot");
    assertEq(lottery.numWinningTickets, 0, "lottery.numWinningTickets");
    assertEq(address(lottery.nft), address(0), "lottery.ticketNFT");

    assertEq(puzzArt.getLotteryPot(), 0, "getLotteryPotSoFar");

    assertEq(puzzArt.totalSupply(), 0, "totalSupply");
    (address r1, uint r2) = puzzArt.royaltyInfo(0, 100);
    assertEq(r1, puzzArt_addr, "royaltyInfo.receiver");
    assertEq(r2, 20, "royaltyInfo.fee");

    (address rec, uint fee) = puzzArt.getRoyaltyInfo();
    assertEq(rec, puzzArt_addr, "getRoyaltyInfo.receiver");
    assertEq(fee, 2000, "getRoyaltyInfo.fee");
  }

  function test_ClaimGasRefunds_WhenOwner() public {
    vm.prank(owner1);
    puzzArt.claimGasRefunds();
  }

  function test_ClaimGasRefunds_WhenNotOwner() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, wallet1));
    puzzArt.claimGasRefunds();
  }
}
