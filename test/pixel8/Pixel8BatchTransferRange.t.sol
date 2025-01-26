// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8 } from "../../src/Pixel8.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { GoodERC721Receiver } from "../utils/TestBase01.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract Pixel8BatchTransferRange is Pixel8TestBase {
  function setUp() public override {
    defaultPixel8Config = _getDefaultPixel8Config();
    defaultPixel8Config.externalTradeThreshold = 1;

    super.setUp();

    vm.prank(owner1);
    pixel8.setPool(pool1);

    vm.startPrank(pool1);
    pixel8.batchMint(wallet1, 1, 4);
    pixel8.batchMint(wallet2, 5, 1);
    vm.stopPrank();
  }

  function test_Pixel8BatchTransferRange_ByOwner_Succeeds() public {
    vm.prank(wallet1);
    pixel8.batchTransferRange(wallet1, wallet2, 2);

    assertEq(pixel8.ownerOf(1), wallet1);
    assertEq(pixel8.ownerOf(2), wallet1);
    assertEq(pixel8.ownerOf(3), wallet2);
    assertEq(pixel8.ownerOf(4), wallet2);
    assertEq(pixel8.ownerOf(5), wallet2);

    assertEq(pixel8.totalSupply(), 5);
    assertEq(pixel8.balanceOf(wallet1), 2);
    assertEq(pixel8.balanceOf(wallet2), 3);

    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 1), 2);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet2, 0), 5);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet2, 1), 4);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet2, 2), 3);
  }

  function test_Pixel8BatchTransferRange_ByPool_Succeeds() public {
    uint256 currentTime = block.timestamp;
    vm.prank(pool1);
    pixel8.batchTransferRange(wallet1, wallet2, 2);

    assertEq(pixel8.ownerOf(4), wallet2);
    assertEq(pixel8.ownerOf(3), wallet2);

    // Check lastCooldownStartTime is updated when transferred from pool
    assertEq(pixel8.lastCooldownStartTime(4), currentTime);
    assertEq(pixel8.lastCooldownStartTime(3), currentTime);

    // Check getTileState returns correct cooldown start time
    Pixel8.TileState memory tileState4 = pixel8.getTileState(4);
    assertEq(tileState4.lastCooldownStartTime, currentTime, "Incorrect last cooldown start time for token 4");
    assertEq(tileState4.owner, wallet2, "Token 4 should be owned by wallet2");

    Pixel8.TileState memory tileState3 = pixel8.getTileState(3);
    assertEq(tileState3.lastCooldownStartTime, currentTime, "Incorrect last cooldown start time for token 3");
    assertEq(tileState3.owner, wallet2, "Token 3 should be owned by wallet2");
  }

  function test_Pixel8BatchTransferRange_NotFromPool_DoesNotUpdateLastCooldownStartTime() public {
    uint256 initialTime = pixel8.lastCooldownStartTime(4);

    // Transfer from wallet1 to wallet2 (not from pool)
    vm.prank(wallet1);
    pixel8.batchTransferRange(wallet1, wallet2, 2);

    // Check lastCooldownStartTime remains unchanged
    assertEq(pixel8.lastCooldownStartTime(4), initialTime);
    assertEq(pixel8.lastCooldownStartTime(3), initialTime);

    // Check getTileState returns correct cooldown start time
    Pixel8.TileState memory tileState4 = pixel8.getTileState(4);
    assertEq(tileState4.lastCooldownStartTime, initialTime, "Incorrect last cooldown start time for token 4");
    assertEq(tileState4.owner, wallet2, "Token 4 should be owned by wallet2");

    Pixel8.TileState memory tileState3 = pixel8.getTileState(3);
    assertEq(tileState3.lastCooldownStartTime, initialTime, "Incorrect last cooldown start time for token 3");
    assertEq(tileState3.owner, wallet2, "Token 3 should be owned by wallet2");
  }

  function test_Pixel8BatchTransferRangeIfNotAuthorised_Fails() public {
    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 4));
    pixel8.batchTransferRange(wallet1, wallet2, 2);
  }

  function test_Pixel8BatchTransferRange_IfAllAuthorised_Succeeds() public {
    vm.startPrank(wallet1);
    pixel8.approve(wallet2, 4);
    pixel8.approve(wallet2, 3);
    vm.stopPrank();

    vm.prank(wallet2);
    pixel8.batchTransferRange(wallet1, wallet2, 2);

    assertEq(pixel8.ownerOf(4), wallet2);
    assertEq(pixel8.ownerOf(3), wallet2);
  }

  function test_Pixel8BatchTransferRange_IfNotAllAuthorised_Fails() public {
    vm.startPrank(wallet1);
    pixel8.approve(wallet2, 4);
    vm.stopPrank();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 3));
    pixel8.batchTransferRange(wallet1, wallet2, 2);
  }

  function test_Pixel8BatchTransferRange_ToZeroAddress_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    pixel8.batchTransferRange(wallet1, address(0), 2);
  }

  function test_Pixel8BatchTransfer_InvokesReceiver() public {
    GoodERC721Receiver good = new GoodERC721Receiver();

    vm.prank(pool1);
    pixel8.batchTransferRange(wallet1, address(good), 2);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, pool1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 4);
    assertEq(r.data, "");

    r = GoodERC721Receiver(good).getReceived(1);
    assertEq(r.operator, pool1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 3);
    assertEq(r.data, "");
  }
}
