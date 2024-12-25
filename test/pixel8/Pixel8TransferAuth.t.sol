// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract Pixel8TransferAuth is Pixel8TestBase {
  function setUp() public override {
    defaultPixel8Config = _getDefaultPixel8Config();
    defaultPixel8Config.externalTradeThreshold = 5;
    super.setUp();

    vm.prank(owner1);
    pixel8.setPool(pool1);

    vm.prank(pool1);
    pixel8.batchMint(wallet1, 1, 2);
  }

  function test_IsApprovedForAll_WithPool() public {
    assertEq(pixel8.isApprovedForAll(wallet1, pool1), true);
    assertEq(pixel8.isApprovedForAll(wallet2, pool1), true);
  }

  function test_AnonTransfer_BeforeThreshold_Fails() public {
    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 1));
    pixel8.transferFrom(wallet1, wallet2, 1);
  }

  function test_ApprovedTransfer_BeforeThreshold_Fails() public {
    vm.prank(wallet1);
    pixel8.approve(wallet2, 1);

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 1));
    pixel8.transferFrom(wallet1, wallet2, 1);
  }

  function test_PoolTransfer_BeforeThreshold_Succeeds() public {
    vm.prank(pool1);
    pixel8.transferFrom(wallet1, wallet2, 1);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet1);
  }

  function _mintUpToThreshold() internal {
    vm.startPrank(pool1);
    pixel8.batchMint(wallet3, 3, pixel8.externalTradeThreshold() - 2);
    vm.stopPrank();
  }

  function test_ApprovedTransfer_AfterThreshold_Succeeds() public {
    _mintUpToThreshold();
    vm.prank(wallet1);
    pixel8.approve(wallet2, 1);

    vm.prank(wallet2);
    pixel8.transferFrom(wallet1, wallet2, 1);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet1);
  }

  function test_AnonTransfer_AfterThreshold_StillFails() public {
    _mintUpToThreshold();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 1));
    pixel8.transferFrom(wallet1, wallet2, 1);
  }

  function test_PoolTransfer_AfterThreshold_StillSucceeds() public {
    _mintUpToThreshold();

    vm.prank(pool1);
    pixel8.transferFrom(wallet1, wallet2, 1);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet1);
  }
}
