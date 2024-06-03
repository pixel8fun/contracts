// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { LotteryNftTestBase } from "./LotteryNftTestBase.sol";
import { GoodERC721Receiver } from "../utils/TestBase01.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract LotteryNftMinting is LotteryNftTestBase {
  function test_MintByMinter_Succeeds() public {
    vm.prank(minter1);
    lotteryNft.batchMint(wallet1, 2);

    assertEq(lotteryNft.ownerOf(1), wallet1);
    assertEq(lotteryNft.ownerOf(2), wallet1);

    assertEq(lotteryNft.totalSupply(), 2);
    assertEq(lotteryNft.balanceOf(wallet1), 2);

    assertEq(lotteryNft.tokenByIndex(0), 1);
    assertEq(lotteryNft.tokenByIndex(1), 2);

    assertEq(lotteryNft.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(lotteryNft.tokenOfOwnerByIndex(wallet1, 1), 2);
  }

  function test_MintByMinter_InvokesReceiver() public {
    GoodERC721Receiver good = new GoodERC721Receiver();

    vm.prank(minter1);
    lotteryNft.batchMint(address(good), 2);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, minter1);
    assertEq(r.from, address(0));
    assertEq(r.tokenId, 1);
    assertEq(r.data, "");

    r = GoodERC721Receiver(good).getReceived(1);
    assertEq(r.operator, minter1);
    assertEq(r.from, address(0));
    assertEq(r.tokenId, 2);
    assertEq(r.data, "");
  }

  function test_MintByNotMinter_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, wallet1));
    lotteryNft.batchMint(wallet1, 2);
  }

  function test_MintEmpty_Fails() public {
    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidBatchSize.selector, uint(0)));
    lotteryNft.batchMint(wallet1, 0);
  }

  function test_MintToZeroAddress_Fails() public {
    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    lotteryNft.batchMint(address(0), 1);
  }
}
