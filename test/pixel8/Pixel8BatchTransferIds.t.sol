// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { GoodERC721Receiver } from "../utils/TestBase01.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract Pixel8BatchTransferIds is Pixel8TestBase {
  function setUp() public override {
    super.setUp();

    vm.prank(owner1);
    pixel8.setPool(pool1);

    vm.startPrank(pool1);
    pixel8.batchMint(wallet1, 1, 2);
    pixel8.batchMint(wallet2, 3, 1);
    vm.stopPrank();
  }

  function _getIdsToTransfer() internal pure returns (uint[] memory) {
    uint[] memory ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;
    return ids;
  }

  function test_Pixel8BatchTransferIds_ByOwner_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.prank(wallet1);
    pixel8.batchTransferIds(wallet1, wallet2, ids);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet2);
    assertEq(pixel8.ownerOf(3), wallet2);

    assertEq(pixel8.totalSupply(), 3);
    assertEq(pixel8.balanceOf(wallet1), 0);
    assertEq(pixel8.balanceOf(wallet2), 3);

    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 0);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet2, 0), 3);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet2, 1), 1);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet2, 2), 2);
  }

  function test_Pixel8BatchTransferIds_ByPool_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();
    uint256 currentTime = block.timestamp;

    vm.prank(pool1);
    pixel8.batchTransferIds(wallet1, wallet2, ids);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet2);

    // Check lastCooldownStartTime is updated when transferred from pool
    assertEq(pixel8.lastCooldownStartTime(1), currentTime);
    assertEq(pixel8.lastCooldownStartTime(2), currentTime);
  }

  function test_Pixel8BatchTransferIds_NotFromPool_DoesNotUpdateLastPoolBuyTime() public {
    uint[] memory ids = _getIdsToTransfer();
    uint256 initialTime = pixel8.lastCooldownStartTime(1);

    // Transfer from wallet1 to wallet2 (not from pool)
    vm.prank(wallet1);
    pixel8.batchTransferIds(wallet1, wallet2, ids);

    // Check lastCooldownStartTime remains unchanged
    assertEq(pixel8.lastCooldownStartTime(1), initialTime);
    assertEq(pixel8.lastCooldownStartTime(2), initialTime);
  }

  function test_Pixel8BatchTransferIdsIfNotAuthorised_Fails() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 1));
    pixel8.batchTransferIds(wallet1, wallet2, ids);
  }

  function test_Pixel8BatchTransferIds_IfAllAuthorised_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.startPrank(wallet1);
    pixel8.approve(wallet2, 1);
    pixel8.approve(wallet2, 2);
    vm.stopPrank();

    vm.prank(wallet2);
    pixel8.batchTransferIds(wallet1, wallet2, ids);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet2);
  }

  function test_Pixel8BatchTransferIds_IfNotAllAuthorised_Succeeds() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.startPrank(wallet1);
    pixel8.approve(wallet2, 1);
    vm.stopPrank();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 2));
    pixel8.batchTransferIds(wallet1, wallet2, ids);
  }

  function test_Pixel8BatchTransferIds_ToZeroAddress_Fails() public {
    uint[] memory ids = _getIdsToTransfer();

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    pixel8.batchTransferIds(wallet1, address(0), ids);
  }

  function test_Pixel8BatchTransfer_InvokesReceiver() public {
    GoodERC721Receiver good = new GoodERC721Receiver();

    uint[] memory ids = _getIdsToTransfer();

    vm.prank(pool1);
    pixel8.batchTransferIds(wallet1, address(good), ids);

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
