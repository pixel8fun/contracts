// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { IERC721Errors } from "openzeppelin/interfaces/draft-IERC6093.sol";
import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";

contract PuzzArtNftTokenUri is PuzzArtNftTestBase {
  function setUp() virtual override public {
    super.setUp();

    vm.startPrank(owner1);
    puzzArt.setLotteryNFT(lotteryNft_addr);
    vm.stopPrank();

    string memory uri = "";

    vm.prank(wallet1);
    _puzzArt_mint(wallet1, 1, uri, 1);        
  }

  function test_TokenUriReturnsDefaultUri() public {
    assertEq(puzzArt.tokenURI(1), _buildDefaultTokenUri(1));
  }

  function test_TokenUriReturnsRevealedUri() public {
    vm.prank(wallet1);
    _puzzArt_reveal(wallet1, 1, "uri", 1);        

    assertEq(puzzArt.tokenURI(1), "uri");
  }
}
