// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { GoodERC721Receiver } from "../utils/TestBase01.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract PuzzArtNftBatchTransferIds is PuzzArtNftTestBase {
  function setUp() public override {
    super.setUp();

    vm.prank(owner1);
    puzzArt.setPool(pool1);

    vm.startPrank(pool1);
    puzzArt.batchMint(wallet1, 1, 2);
    puzzArt.batchMint(wallet2, 3, 1);
    vm.stopPrank();
  }

  function _getIdsToTransfer() internal pure returns (uint[] memory) {
    uint[] memory ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;
    return ids;
  }

  function test_PuzzArtNftBatchTransferIds_ByOwner_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.prank(wallet1);
    puzzArt.batchTransferIds(wallet1, wallet2, ids);

    assertEq(puzzArt.ownerOf(1), wallet2);
    assertEq(puzzArt.ownerOf(2), wallet2);
    assertEq(puzzArt.ownerOf(3), wallet2);

    assertEq(puzzArt.totalSupply(), 3);
    assertEq(puzzArt.balanceOf(wallet1), 0);
    assertEq(puzzArt.balanceOf(wallet2), 3);

    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 0);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet2, 0), 3);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet2, 1), 1);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet2, 2), 2);
  }

  function test_PuzzArtNftBatchTransferIds_ByPool_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.prank(pool1);
    puzzArt.batchTransferIds(wallet1, wallet2, ids);

    assertEq(puzzArt.ownerOf(1), wallet2);
    assertEq(puzzArt.ownerOf(2), wallet2);
  }

  function test_PuzzArtNftBatchTransferIdsIfNotAuthorised_Fails() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 1));
    puzzArt.batchTransferIds(wallet1, wallet2, ids);
  }

  function test_PuzzArtNftBatchTransferIds_IfAllAuthorised_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.startPrank(wallet1);
    puzzArt.approve(wallet2, 1);
    puzzArt.approve(wallet2, 2);
    vm.stopPrank();

    vm.prank(wallet2);
    puzzArt.batchTransferIds(wallet1, wallet2, ids);

    assertEq(puzzArt.ownerOf(1), wallet2);
    assertEq(puzzArt.ownerOf(2), wallet2);
  }

  function test_PuzzArtNftBatchTransferIds_IfNotAllAuthorised_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.startPrank(wallet1);
    puzzArt.approve(wallet2, 1);
    vm.stopPrank();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 2));
    puzzArt.batchTransferIds(wallet1, wallet2, ids);
  }

  function test_PuzzArtNftBatchTransferIds_ToZeroAddress_Fails() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    puzzArt.batchTransferIds(wallet1, address(0), ids);
  }

  function test_PuzzArtNftBatchTransfer_InvokesReceiver() public {
    GoodERC721Receiver good = new GoodERC721Receiver();

    uint[] memory ids = _getIdsToTransfer();

    vm.prank(pool1);
    puzzArt.batchTransferIds(wallet1, address(good), ids);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, pool1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 1);
    assertEq(r.data, "");

    r = GoodERC721Receiver(good).getReceived(1);
    assertEq(r.operator, pool1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 2);
    assertEq(r.data, "");
  }
}
