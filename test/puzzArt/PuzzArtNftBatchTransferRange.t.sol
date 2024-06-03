// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { GoodERC721Receiver } from "../utils/TestBase01.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract PuzzArtNftBatchTransferRange is PuzzArtNftTestBase {
  function setUp() public override {
    super.setUp();

    vm.prank(owner1);
    puzzArt.setPool(pool1);

    vm.startPrank(pool1);
    puzzArt.batchMint(wallet1, 1, 4);
    puzzArt.batchMint(wallet2, 5, 1);
    vm.stopPrank();
  }

  function test_PuzzArtNftBatchTransferRange_ByOwner_Succeeds() public {
    vm.prank(wallet1);
    puzzArt.batchTransferRange(wallet1, wallet2, 2);

    assertEq(puzzArt.ownerOf(1), wallet1);
    assertEq(puzzArt.ownerOf(2), wallet1);
    assertEq(puzzArt.ownerOf(3), wallet2);
    assertEq(puzzArt.ownerOf(4), wallet2);
    assertEq(puzzArt.ownerOf(5), wallet2);

    assertEq(puzzArt.totalSupply(), 5);
    assertEq(puzzArt.balanceOf(wallet1), 2);
    assertEq(puzzArt.balanceOf(wallet2), 3);

    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 1), 2);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet2, 0), 5);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet2, 1), 4);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet2, 2), 3);
  }

  function test_PuzzArtNftBatchTransferRange_ByPool_Succeeds() public {
    vm.prank(pool1);
    puzzArt.batchTransferRange(wallet1, wallet2, 2);

    assertEq(puzzArt.ownerOf(4), wallet2);
    assertEq(puzzArt.ownerOf(3), wallet2);
  }

  function test_PuzzArtNftBatchTransferRangeIfNotAuthorised_Fails() public {
    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 4));
    puzzArt.batchTransferRange(wallet1, wallet2, 2);
  }

  function test_PuzzArtNftBatchTransferRange_IfAllAuthorised_Succeeds() public {
    vm.startPrank(wallet1);
    puzzArt.approve(wallet2, 4);
    puzzArt.approve(wallet2, 3);
    vm.stopPrank();

    vm.prank(wallet2);
    puzzArt.batchTransferRange(wallet1, wallet2, 2);

    assertEq(puzzArt.ownerOf(4), wallet2);
    assertEq(puzzArt.ownerOf(3), wallet2);
  }

  function test_PuzzArtNftBatchTransferRange_IfNotAllAuthorised_Fails() public {
    vm.startPrank(wallet1);
    puzzArt.approve(wallet2, 4);
    vm.stopPrank();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 3));
    puzzArt.batchTransferRange(wallet1, wallet2, 2);
  }

  function test_PuzzArtNftBatchTransferRange_ToZeroAddress_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    puzzArt.batchTransferRange(wallet1, address(0), 2);
  }

  function test_PuzzArtNftBatchTransfer_InvokesReceiver() public {
    GoodERC721Receiver good = new GoodERC721Receiver();

    vm.prank(pool1);
    puzzArt.batchTransferRange(wallet1, address(good), 2);

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
