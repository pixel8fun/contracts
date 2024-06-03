// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { PuzzArt } from "src/PuzzArt.sol";
import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "src/LibErrors.sol";


contract PuzzArtNftLottery is PuzzArtNftTestBase {
  function setUp() public override {
    super.setUp();

    vm.startPrank(owner1);
    puzzArt.setLotteryNFT(lotteryNft_addr);
    puzzArt.setPool(pool1);    
    vm.stopPrank();
  }

  function test_DrawLottery_WhenNotOwner_Fails() public {
    uint[] memory winners = new uint[](0);

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, wallet1));
    puzzArt.drawLottery(winners);

    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, minter1));
    puzzArt.drawLottery(winners);

    vm.prank(pool1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, pool1));
    puzzArt.drawLottery(winners);
  }

  function test_DrawLottery_WhenNotYetReady_Fails() public {
    assertEq(puzzArt.canDrawLottery(), false, "canDrawLottery");
    
    vm.prank(owner1);
    vm.expectRevert(LibErrors.LotteryCannotBeDrawnYet.selector);
    uint[] memory winners = new uint[](0);
    puzzArt.drawLottery(winners);
  }

  function test_DrawLottery_WhenNotYetSetNumWinningTickets_Fails() public {
    _mintAndRevealTiles();

    assertEq(puzzArt.canDrawLottery(), false, "canDrawLottery");

    uint[] memory winners = _buildLotteryWinnerList(1);

    vm.prank(owner1);
    vm.expectRevert(LibErrors.LotteryNumWinningTicketsNotSet.selector);
    puzzArt.drawLottery(winners);
  }

  function test_DrawLottery_WhenTileRevealThresholdReached_Succeeds() public {
    _mintAndRevealTiles();

    uint[] memory winners = _buildLotteryWinnerList(1);

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    assertEq(puzzArt.canDrawLottery(), true, "canDrawLottery");
    puzzArt.drawLottery(winners);
    vm.stopPrank();
  }

  function test_DrawLottery_WhenDeadlinePassed_Succeeds() public {
    vm.warp(block.timestamp + 11);

    uint[] memory winners = _buildLotteryWinnerList(1);

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    assertEq(puzzArt.canDrawLottery(), true, "canDrawLottery");
    puzzArt.drawLottery(winners);
    vm.stopPrank();
  }

  function test_DrawLottery_Again_Fails() public {
    _mintAndRevealTiles();

    uint[] memory winners = _buildLotteryWinnerList(1);

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    puzzArt.drawLottery(winners);
    vm.stopPrank();

    assertEq(puzzArt.canDrawLottery(), false, "canDrawLottery");

    vm.prank(owner1);
    vm.expectRevert(LibErrors.LotteryAlreadyDrawn.selector);
    puzzArt.drawLottery(winners);
  }

  function test_GetLotteryPot_PriorToDrawingLottery_CalculatesBasedOnBalance() public {
    payable(puzzArt_addr).transfer(0.0006 ether);

    assertEq(puzzArt.getLotteryPot(), 0.0003 ether, "getLotteryPot");
  }

  function test_DrawLottery_SetsUpLotteryPot() public {
    _mintAndRevealTiles();

    uint[] memory winners = _buildLotteryWinnerList(1);

    payable(puzzArt_addr).transfer(0.0005 ether);

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    puzzArt.drawLottery(winners);
    vm.stopPrank();

    PuzzArt.Lottery memory lottery = puzzArt.getLottery();
    assertEq(lottery.drawnPot, 0.00025 ether, "lottery.drawnPot");
  }

  function test_GetLotteryPot_PostDrawingLottery_JustReturnsDrawnLottery() public {
    _mintAndRevealTiles();

    uint[] memory winners = _buildLotteryWinnerList(1);

    payable(puzzArt_addr).transfer(0.0005 ether);

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    puzzArt.drawLottery(winners);
    vm.stopPrank();

    assertEq(puzzArt.getLotteryPot(), 0.00025 ether, "getLotteryPot - 1");

    payable(puzzArt_addr).transfer(0.0005 ether);

    assertEq(puzzArt.getLotteryPot(), 0.00025 ether, "getLotteryPot - 2");    
  }

  function test_DrawLottery_UpdatesRoyaltyInfo() public {
    _mintAndRevealTiles();

    uint[] memory winners = _buildLotteryWinnerList(1);

    PuzzArt.DevRoyalties memory devRoyalties = puzzArt.getDevRoyalties();

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    puzzArt.drawLottery(winners);
    vm.stopPrank();

    (address rr, uint rf) = puzzArt.getRoyaltyInfo();
    assertEq(rr, devRoyalties.receiver, "royaltyReceiver");
    assertEq(rf, devRoyalties.feeBips, "royaltyFeeBips");
  }

  function test_DrawLottery_SavesWinners() public {
    _mintAndRevealTiles();

    uint[] memory winners = new uint[](3);
    winners[0] = 4;
    winners[1] = 5;
    winners[2] = 6;

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    puzzArt.drawLottery(winners);
    vm.stopPrank();

    PuzzArt.Lottery memory lottery = puzzArt.getLottery();
    assertEq(lottery.winners.length, 3, "winners.length");
    assertEq(lottery.winners[0], 4, "winners[0]");
    assertEq(lottery.winners[1], 5, "winners[1]");
    assertEq(lottery.winners[2], 6, "winners[2]");
  }

  function test_DrawLottery_WithdrawsDevRoyalties() public {
    _drawLotteryWinners();
    assertEq(owner1.balance, 0.0009 ether);
  }

  function test_IsWinner_WhenNotYetDrawn() public {
    assertEq(puzzArt.isLotteryWinner(1), false);
  }

  function test_IsWinner() public {
    _drawLotteryWinners();

    assertEq(puzzArt.isLotteryWinner(1), false);
    assertEq(puzzArt.isLotteryWinner(2), false);
    assertEq(puzzArt.isLotteryWinner(3), false);
    assertEq(puzzArt.isLotteryWinner(4), true);
    assertEq(puzzArt.isLotteryWinner(5), true);
    assertEq(puzzArt.isLotteryWinner(6), true);
    assertEq(puzzArt.isLotteryWinner(7), false);
    assertEq(puzzArt.isLotteryWinner(8), false);
    assertEq(puzzArt.isLotteryWinner(9), false);
    assertEq(puzzArt.isLotteryWinner(10), false);
  }

  function test_canClaimWinnings_WhenNotYetDrawn() public {
    assertEq(puzzArt.canClaimLotteryWinnings(1), false);
  }

  function test_canClaimWinnings_WhenDrawnButNotWinningTicket() public {
    _drawLotteryWinners();

    assertEq(puzzArt.canClaimLotteryWinnings(1), false);
  }

  function test_canClaimWinnings_WhenDrawn_AndWinningTicket() public {
    _drawLotteryWinners();

    assertEq(puzzArt.canClaimLotteryWinnings(4), true);
  }

  function test_claimWinnings_WhenNotDrawn_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.LotteryCannotClaimWinnings.selector, uint(1)));
    puzzArt.claimLotteryWinnings(1);
  }

  function test_claimWinnings_WhenDrawn_ButNotWinningTicket_Fails() public {
    _drawLotteryWinners();

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.LotteryCannotClaimWinnings.selector, uint(1)));
    puzzArt.claimLotteryWinnings(1);
  }

  function test_claimWinnings_WhenDrawn_AndWinningTicket_Succeeds() public {
    _drawLotteryWinners();
    
    assertEq(puzzArt_addr.balance, 0.0018 ether - 0.0009 ether /* dev royalties */);

    vm.prank(wallet1);
    puzzArt.claimLotteryWinnings(4);

    // check status
    assertEq(puzzArt.canClaimLotteryWinnings(4), false);
    assertEq(puzzArt.lotteryWinningsClaimed(4), true);

    // check balances have been updated
    assertEq(wallet1.balance, 0.0003 ether);
    assertEq(puzzArt_addr.balance, 0.0018 ether - 0.0009 ether - 0.0003 ether);
  }

  function test_claimWinnings_WhenDrawn_AndAnyoneCanClaimForWinningTicket() public {
    _drawLotteryWinners();
    
    assertEq(puzzArt_addr.balance, 0.0018 ether - 0.0009 ether /* dev royalties */);

    vm.prank(wallet2); // not the ticket owner but still works
    puzzArt.claimLotteryWinnings(4);

    // check status
    assertEq(puzzArt.canClaimLotteryWinnings(4), false);
    assertEq(puzzArt.lotteryWinningsClaimed(4), true);

    // check balances have been updated
    assertEq(wallet1.balance, 0.0003 ether);
    assertEq(puzzArt_addr.balance, 0.0018 ether - 0.0009 ether - 0.0003 ether);
  }

  function test_claimWinnings_WhenDrawn_AndCannotClaimTwice() public {
    _drawLotteryWinners();
    
    vm.prank(wallet1);
    puzzArt.claimLotteryWinnings(4);

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.LotteryCannotClaimWinnings.selector, 4));
    puzzArt.claimLotteryWinnings(4);
  }

  // Helper methods

  function _mintAndRevealTiles() internal {
    vm.prank(pool1);
    puzzArt.batchMint(wallet1, 1, 10);

    vm.startPrank(wallet1);

    for (uint i = 1; i <= 10; i++) {
      _puzzArt_reveal(wallet1, i, "uri1", 1);
    }

    vm.stopPrank();
  }

  function _buildLotteryWinnerList(uint _count) internal returns (uint[] memory winners) {
    winners = new uint[](_count);
    for (uint i = 0; i < _count; i++) {
      winners[i] = i + 1;
    }
  }

  function _drawLotteryWinners() internal {
    _mintAndRevealTiles();

    /*
    See PuzzArtNftTestBase for this config...

    dev royalty (10% of trade value) = 0.00009 ether
    lottery pot (10% of trade value) = 0.00009 ether
    total fee = 20%

    total pot= 0.00018 ether
    dev pot = 0.00009 ether
    lottery pot = 0.00009 ether
    */
    payable(puzzArt_addr).transfer(0.0018 ether);

    uint[] memory winners = new uint[](3);
    winners[0] = 4;
    winners[1] = 5;
    winners[2] = 6;

    vm.startPrank(owner1);
    puzzArt.setLotteryNumWinningTickets(winners.length);
    puzzArt.drawLottery(winners);
    vm.stopPrank();
  }
}
