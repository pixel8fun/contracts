// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { IERC721Errors } from "openzeppelin/interfaces/draft-IERC6093.sol";
import { LotteryNftTestBase } from "./LotteryNftTestBase.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";

contract LotteryNftTokenUri is LotteryNftTestBase {
  function setUp() virtual override public {
    super.setUp();

    vm.prank(minter1);
    lotteryNft.batchMint(wallet1, 1);
  }

  function test_TokenUriReturnsDefaultUri() public {
    assertEq(lotteryNft.tokenURI(1), _buildDefaultTokenUri(1));
  }
}
