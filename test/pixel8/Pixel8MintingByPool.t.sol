// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { GoodERC721Receiver } from "../utils/TestBase01.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract Pixel8MintingByPool is Pixel8TestBase {
  function setUp() public override {
    super.setUp();

    vm.prank(owner1);
    pixel8.setPool(pool1);
  }

  function test_MintByPool_Succeeds() public {
    uint256 currentTime = block.timestamp;
    vm.prank(pool1);
    pixel8.batchMint(wallet1, 1, 2);

    assertEq(pixel8.ownerOf(1), wallet1);
    assertEq(pixel8.ownerOf(2), wallet1);

    assertEq(pixel8.totalSupply(), 2);
    assertEq(pixel8.balanceOf(wallet1), 2);

    assertEq(pixel8.tokenByIndex(0), 1);
    assertEq(pixel8.tokenByIndex(1), 2);

    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 1), 2);

    // Check lastPoolBuyTime is set correctly
    assertEq(pixel8.lastPoolBuyTime(1), currentTime);
    assertEq(pixel8.lastPoolBuyTime(2), currentTime);
  }

  function test_MintByPool_InvokesReceiver() public {
    GoodERC721Receiver good = new GoodERC721Receiver();

    vm.prank(pool1);
    pixel8.batchMint(address(good), 1, 2);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, pool1);
    assertEq(r.from, address(0));
    assertEq(r.tokenId, 1);
    assertEq(r.data, "");

    r = GoodERC721Receiver(good).getReceived(1);
    assertEq(r.operator, pool1);
    assertEq(r.from, address(0));
    assertEq(r.tokenId, 2);
    assertEq(r.data, "");
  }

  function test_MintByNotPool_Fails() public {
    vm.prank(owner1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, owner1));
    pixel8.batchMint(wallet1, 1, 2);

    vm.prank(authoriser1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, authoriser1));
    pixel8.batchMint(wallet1, 1, 2);
  }

  function test_MintEmpty_Fails() public {
    vm.prank(pool1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidBatchSize.selector, uint(0)));
    pixel8.batchMint(wallet1, 1, 0);
  }

  function test_MintToZeroAddress_Fails() public {
    vm.prank(pool1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    pixel8.batchMint(address(0), 1, 1);
  }

  function test_MintAlreadyMintedToken_Fails() public {
    vm.prank(pool1);
    pixel8.batchMint(wallet1, 1, 3);

    vm.prank(pool1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenAlreadyMinted.selector, uint(3)));
    pixel8.batchMint(wallet1, 3, 1);
  }
}
