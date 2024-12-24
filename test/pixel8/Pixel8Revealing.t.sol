// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";

contract Pixel8Revealing is Pixel8TestBase {
  function setUp() virtual override public {
    super.setUp();

    vm.prank(owner1);
    pixel8.setPool(pool1);

    vm.prank(pool1);
    pixel8.batchMint(wallet1, 1, 3);
  }

  function test_RevealWithAuthorisation_Succeeds() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1");  

    assertEq(pixel8.tokenURI(1), "uri1", "post 1: token uri");
    assertEq(pixel8.revealed(1), true, "post 1: revealed state");
    assertEq(pixel8.numRevealed(), 1, "post 1: revealed count");

    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 2, "uri2");

    assertEq(pixel8.tokenURI(2), "uri2", "post 2: token uri");
    assertEq(pixel8.revealed(2), true, "post 2: revealed state");
    assertEq(pixel8.numRevealed(), 2, "post 2: revealed count");
  }

  function test_RevealWithAuthorisation_EmitsEvent() public {
    vm.recordLogs();

    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    // 1 metadata update
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 1, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("MetadataUpdate(uint256)"),
        "Invalid event signature"
    );
    (uint256 tokenId) = abi.decode(entries[0].data, (uint256));
    assertEq(tokenId, 1, "Invalid token id");
  }

  function test_RevealWithAuthorisation_WhenCallerNotRevealer_Succeeds() public {
    vm.prank(wallet2);
    _pixel8_reveal(wallet1, 1, "uri1");

    assertEq(pixel8.tokenURI(1), "uri1", "post 1: token uri");
    assertEq(pixel8.revealed(1), true, "post 1: revealed state");
    assertEq(pixel8.numRevealed(), 1, "post 1: revealed count");
  }

  function test_RevealWithAuthorisation_AwardsPoints() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1");    

    assertEq(pixel8.tokenURI(1), "uri1");
    assertEq(pixel8.revealed(1), true);

    vm.startPrank(wallet2);
    _pixel8_reveal(wallet2, 2, "uri2");    
    _pixel8_reveal(wallet2, 3, "uri3");    
    vm.stopPrank();

    assertEq(pixel8.tokenURI(2), "uri2");
    assertEq(pixel8.revealed(2), true);

    assertEq(pixel8.points(wallet1), 50);
    assertEq(pixel8.points(wallet2), 100);
  }

  function test_RevealWithNotAuthorisation_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.reveal(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: 1,
      uri: "uri1",
      authSig: _computeOwnerSig(
        abi.encodePacked(wallet1, uint(1), "uri1"),
        block.timestamp + 10 seconds
      )
    }));

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.reveal(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: 1,
      uri: "uri1",
      authSig: _computeSig(
        0x123,
        abi.encodePacked(wallet1, uint(1), "uri1"),
        block.timestamp + 10 seconds
      )
    }));
  }

  function test_RevealWithExpiredSignature_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureExpired.selector, wallet1));
    pixel8.reveal(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: 1,
      uri: "uri",
      authSig: _computeAuthoriserSig(
        abi.encodePacked(wallet1, uint(1), "uri"),
        block.timestamp - 1 seconds
      )
    }));
  }

  function test_RevealWhenSignatureAlreadyUsed_Fails() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1");    

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureAlreadyUsed.selector, wallet1));
    _pixel8_reveal(wallet1, 1, "uri1");        
  }

  function test_RevealWhenAlreadyRevealed_Fails() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1");    

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.AlreadyRevealed.selector, 1));
    _pixel8_reveal(wallet1, 1, "uri2");    
  }

  function test_RevealNonMintedToken_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenNotMinted.selector, 4));
    _pixel8_reveal(wallet1, 4, "uri1");    
  }
}
