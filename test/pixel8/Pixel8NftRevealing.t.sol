// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";
import { Pixel8NftTestBase } from "./Pixel8NftTestBase.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { Auth } from "src/Auth.sol";
import { LibErrors } from "src/LibErrors.sol";

contract Pixel8NftRevealing is Pixel8NftTestBase {
  function setUp() virtual override public {
    super.setUp();

    vm.startPrank(wallet1);
    _pixel8_mint(wallet1, 1, "", 1);
    _pixel8_mint(wallet1, 2, "", 1);
    vm.stopPrank();
  }

  function test_RevealWithMinterAuthorisation_Succeeds() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1", 1);

    assertEq(pixel8.tokenURI(1), "uri1", "post 1: token uri");
    assertEq(pixel8.revealed(1), true, "post 1: revealed state");
    assertEq(pixel8.numRevealed(), 1, "post 1: revealed count");

    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 2, "uri2", 1);

    assertEq(pixel8.tokenURI(2), "uri2", "post 2: token uri");
    assertEq(pixel8.revealed(2), true, "post 2: revealed state");
    assertEq(pixel8.numRevealed(), 2, "post 2: revealed count");
  }

  function test_RevealWithMinterAuthorisation_EmitsEvent() public {
    vm.recordLogs();

    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1", 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    // 1 metadata update -> 1 lottery ticket minted
    assertEq(entries.length, 2, "Invalid entry count");
    assertEq(entries[0].topics.length, 1, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("MetadataUpdate(uint256)"),
        "Invalid event signature"
    );
    (uint256 tokenId) = abi.decode(entries[0].data, (uint256));
    assertEq(tokenId, 1, "Invalid token id");
  }

  function test_RevealWithMinterAuthorisation_WhenCallerNotRevealer_Succeeds() public {
    vm.prank(wallet2);
    _pixel8_reveal(wallet1, 1, "uri1", 1);

    assertEq(pixel8.tokenURI(1), "uri1", "post 1: token uri");
    assertEq(pixel8.revealed(1), true, "post 1: revealed state");
    assertEq(pixel8.numRevealed(), 1, "post 1: revealed count");
  }

  function test_RevealWithMinterAuthorisation_AwardsLotteryTickets() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1", 1);    

    assertEq(pixel8.tokenURI(1), "uri1");
    assertEq(pixel8.revealed(1), true);

    vm.prank(wallet2);
    _pixel8_reveal(wallet2, 2, "uri2", 0);    

    assertEq(pixel8.tokenURI(2), "uri2");
    assertEq(pixel8.revealed(2), true);
  }

  function test_RevealWithNotMinterAuthorisation_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.reveal(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: 1,
      uri: "uri1",
      lotteryTickets: 1,
      authSig: _computeOwnerSig(
        abi.encodePacked(wallet1, uint(1), "uri1", uint(1)),
        block.timestamp + 10 seconds
      )
    }));

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.reveal(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: 1,
      uri: "uri1",
      lotteryTickets: 1,
      authSig: _computeSig(
        0x123,
        abi.encodePacked(wallet1, uint(1), "uri1", uint(1)),
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
      lotteryTickets: 1,
      authSig: _computeMinterSig(
        abi.encodePacked(wallet1, uint(1), "uri", uint(1)),
        block.timestamp - 1 seconds
      )
    }));
  }

  function test_RevealWhenSignatureAlreadyUsed_Fails() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1", 1);    

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureAlreadyUsed.selector, wallet1));
    _pixel8_reveal(wallet1, 1, "uri1", 1);        
  }

  function test_RevealWhenAlreadyRevealed_Fails() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1", 1);    

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.AlreadyRevealed.selector, 1));
    _pixel8_reveal(wallet1, 1, "uri2", 1);    
  }

  function test_RevealNonMintedToken_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenNotMinted.selector, 3));
    _pixel8_reveal(wallet1, 3, "uri1", 1);    
  }
}
