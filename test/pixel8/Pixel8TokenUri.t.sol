// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { IERC721Errors } from "openzeppelin/interfaces/draft-IERC6093.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";

contract Pixel8TokenUri is Pixel8TestBase {
  function setUp() virtual override public {
    super.setUp();

    string memory uri = "";

    vm.prank(wallet1);
    _pixel8_mint(wallet1, 1, uri, 1);        
  }

  function test_TokenUriReturnsDefaultUri() public {
    assertEq(pixel8.tokenURI(1), _buildDefaultTokenUri(1));
  }

  function test_TokenUriReturnsRevealedUri() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri", 1);        

    assertEq(pixel8.tokenURI(1), "uri");
  }
}
