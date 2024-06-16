// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract Pixel8TransferAuth is Pixel8TestBase {
  function setUp() public override {
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

  function test_AnonTransfer_Fails() public {
    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, 1));
    pixel8.transferFrom(wallet1, wallet2, 1);
  }

  function test_ApprovedTransfer_Succeeds() public {
    vm.prank(wallet1);
    pixel8.approve(wallet2, 1);

    vm.prank(wallet2);
    pixel8.transferFrom(wallet1, wallet2, 1);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet1);
  }

  function test_PoolTransfer_Succeeds() public {
    vm.prank(pool1);
    pixel8.transferFrom(wallet1, wallet2, 1);

    assertEq(pixel8.ownerOf(1), wallet2);
    assertEq(pixel8.ownerOf(2), wallet1);
  }
}
