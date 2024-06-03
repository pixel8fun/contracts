// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { GoodERC721Receiver } from "../utils/TestBase01.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract PuzzArtNftMintingByPool is PuzzArtNftTestBase {
  function setUp() public override {
    super.setUp();

    vm.prank(owner1);
    puzzArt.setPool(pool1);
  }

  function test_MintByPool_Succeeds() public {
    vm.prank(pool1);
    puzzArt.batchMint(wallet1, 1, 2);

    assertEq(puzzArt.ownerOf(1), wallet1);
    assertEq(puzzArt.ownerOf(2), wallet1);

    assertEq(puzzArt.totalSupply(), 2);
    assertEq(puzzArt.balanceOf(wallet1), 2);

    assertEq(puzzArt.tokenByIndex(0), 1);
    assertEq(puzzArt.tokenByIndex(1), 2);

    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 1), 2);
  }

  function test_MintByPool_InvokesReceiver() public {
    GoodERC721Receiver good = new GoodERC721Receiver();

    vm.prank(pool1);
    puzzArt.batchMint(address(good), 1, 2);

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
    puzzArt.batchMint(wallet1, 1, 2);

    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, minter1));
    puzzArt.batchMint(wallet1, 1, 2);
  }

  function test_MintEmpty_Fails() public {
    vm.prank(pool1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidBatchSize.selector, uint(0)));
    puzzArt.batchMint(wallet1, 1, 0);
  }

  function test_MintToZeroAddress_Fails() public {
    vm.prank(pool1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    puzzArt.batchMint(address(0), 1, 1);
  }

  function test_MintAlreadyMintedToken_Fails() public {
    vm.prank(pool1);
    puzzArt.batchMint(wallet1, 1, 3);

    vm.prank(pool1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenAlreadyMinted.selector, uint(3)));
    puzzArt.batchMint(wallet1, 3, 1);
  }
}
