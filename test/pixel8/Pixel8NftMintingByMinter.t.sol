// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;


import {console2 as c} from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { Pixel8NftTestBase } from "./Pixel8NftTestBase.sol";
import { Auth } from "src/Auth.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";

contract Pixel8NftMintingByMinter is Pixel8NftTestBase {
  function setUp() virtual override public {
    super.setUp();

    vm.startPrank(owner1);
    pixel8.setLotteryNFT(lotteryNft_addr);
    vm.stopPrank();
  }

  function test_MintWithMinterAuthorisation_Succeeds() public {
    uint id = 2;
    string memory uri = "";

    vm.prank(wallet1);
    _pixel8_mint(wallet1, id, uri, 1);

    assertEq(pixel8.ownerOf(2), wallet1);
    assertEq(pixel8.totalSupply(), 1);
    assertEq(pixel8.balanceOf(wallet1), 1);
    assertEq(pixel8.tokenByIndex(0), 2);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 2);
    assertEq(pixel8.tokenURI(2), _buildDefaultTokenUri(2));

    id = 3;
    uri = "uri3";

    vm.prank(wallet1);
    _pixel8_mint(wallet1, id, uri, 1);

    assertEq(pixel8.ownerOf(3), wallet1);
    assertEq(pixel8.totalSupply(), 2);
    assertEq(pixel8.balanceOf(wallet1), 2);
    assertEq(pixel8.tokenByIndex(1), 3);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 1), 3);
    assertEq(pixel8.tokenURI(3), "uri3");
  }

  function test_MintWithMinterAuthorisation_EmitsEvent() public {
    vm.recordLogs();

    vm.prank(wallet1);
    _pixel8_mint(wallet1, 1, "uri", 4);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    // 1 pixel8 mint + 1 metadata update + 4 lottery mints
    assertEq(entries.length, 6, "Invalid entry count");
    assertEq(entries[1].topics.length, 1, "Invalid event count");
    assertEq(
        entries[1].topics[0],
        keccak256("MetadataUpdate(uint256)"),
        "Invalid event signature"
    );
    (uint256 tokenId) = abi.decode(entries[1].data, (uint256));
    assertEq(tokenId, 1, "Invalid token id");
  }

  function test_MintWithMinterAuthorisation_WhenCallerNotOwner_Succeeds() public {
    uint id = 2;
    string memory uri = "";

    vm.prank(wallet2);
    _pixel8_mint(wallet1, id, uri, 1);

    assertEq(pixel8.ownerOf(2), wallet1);
    assertEq(pixel8.totalSupply(), 1);
    assertEq(pixel8.balanceOf(wallet1), 1);
    assertEq(pixel8.tokenByIndex(0), 2);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 2);
    assertEq(pixel8.tokenURI(2), _buildDefaultTokenUri(2));
  }

  function test_MintWithMinterAuthorisation_AwardsLotteryTickets() public {
    uint id = 1;
    string memory uri = "";

    vm.prank(wallet1);
    _pixel8_mint(wallet1, id, uri, 4);

    vm.prank(wallet1);
    _pixel8_mint(wallet1, id + 1, uri, 5);

    vm.prank(wallet2);
    _pixel8_mint(wallet2, id + 2, uri, 0);

    assertEq(lotteryNft.balanceOf(wallet1), 9); 
    assertEq(lotteryNft.balanceOf(wallet2), 0);
  }

  function test_MintWithMinterAuthorisation_AndUriSet_RevealsTheToken() public {
    uint id = 1;
    string memory uri = "uri";

    vm.recordLogs();

    vm.prank(wallet1);
    _pixel8_mint(wallet1, id, uri, 4);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    assertEq(pixel8.tokenURI(1), "uri", "token uri");
    assertEq(pixel8.revealed(1), true, "revealed state");
    assertEq(pixel8.numRevealed(), 1, "revealed count");

    // Mint pixel8 -> Set metadata -> 4 x Mint lottery
    assertEq(entries.length, 6, "Invalid entry count");
    assertEq(entries[1].topics.length, 1, "Invalid event count");
    assertEq(
        entries[1].topics[0],
        keccak256("MetadataUpdate(uint256)"),
        "Invalid event signature"
    );
    (uint256 tokenId) = abi.decode(entries[1].data, (uint256));
    assertEq(tokenId, 1, "Invalid token id");
  }

  function test_MintWithNotMinterAuthorisation_Fails() public {
    uint id = 1;
    string memory uri = "";

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.mint(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: id,
      uri: uri,
      lotteryTickets: 1,
      authSig: _computeOwnerSig(
        abi.encodePacked(wallet1, id, uri), 
        block.timestamp + 10 seconds
      )
    }));
  }

  function test_MintBadSignature_Fails() public {
    uint id = 1;
    string memory uri = "";

    Auth.Signature memory sig = Auth.Signature({
      signature: bytes(""),
      deadline: block.timestamp + 10 seconds
    });

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.mint(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: id,
      uri: uri,
      lotteryTickets: 1,
      authSig: sig
    }));
  }

  function test_MintExpiredSignature_Fails() public {
    uint id = 1;
    string memory uri = "";

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureExpired.selector, wallet1));
    pixel8.mint(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: id,
      uri: uri,
      lotteryTickets: 1,
      authSig: _computeMinterSig(
        abi.encodePacked(wallet1, id, uri, uint(1)), 
        block.timestamp - 1 seconds
      )
    }));
  }

  function test_MintSignatureAlreadyUsed_Fails() public {
    uint id = 1;
    string memory uri = "";

    vm.prank(wallet1);
    _pixel8_mint(wallet1, id, uri, 1);

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureAlreadyUsed.selector, wallet1));
    _pixel8_mint(wallet1, id, uri, 1);
  }

  function test_MintAlreadyMintedToken_Fails() public {
    uint id = 1;
    string memory uri = "";

    vm.prank(wallet1);
    _pixel8_mint(wallet1, id, uri, 1);

    uri = "uri2";

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenAlreadyMinted.selector, 1));
    _pixel8_mint(wallet1, id, uri, 1);
  }
}
