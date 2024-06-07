// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { Pixel8NftTestBase } from "./Pixel8NftTestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "src/LibErrors.sol";


contract Pixel8NftSetLotteryNft is Pixel8NftTestBase {
  function test_SetLotteryNft_WhenOwner_Succeeds() public {
    vm.prank(owner1);
    pixel8.setLotteryNFT(lotteryNft_addr);
    assertEq(address(pixel8.getLottery().nft), address(lotteryNft_addr));
  }

  function test_SetLotteryNft_WhenNotOwner_Fails() public {
    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, minter1));
    pixel8.setLotteryNFT(address(0x789));

    address random = address(0x8876);
    vm.prank(random);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
    pixel8.setLotteryNFT(address(0x789));
  }

  function test_SetLotteryNft_WhenAlreadySet_Fails() public {
    vm.prank(owner1);
    pixel8.setLotteryNFT(lotteryNft_addr);

    vm.prank(owner1);
    vm.expectRevert(LibErrors.LotteryNFTAlreadySet.selector);
    pixel8.setLotteryNFT(lotteryNft_addr);
  }

  function test_SetLotteryNft_WhenInvalidInterface_Fails() public {
    vm.prank(owner1);
    vm.expectRevert();
    pixel8.setLotteryNFT(vm.addr(0x123));

    vm.prank(owner1);
    vm.expectRevert(LibErrors.LotteryNFTInvalid.selector);
    pixel8.setLotteryNFT(pixel8_addr);
  }
}
