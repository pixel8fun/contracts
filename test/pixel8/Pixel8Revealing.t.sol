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

    vm.startPrank(owner1);
    pixel8.setPool(pool1);
    gameStats.setPool(pool1);
    vm.stopPrank();

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

    assertEq(gameStats.points(pixel8_addr, wallet1), 50);
    assertEq(gameStats.points(pixel8_addr, wallet2), 100);
  }

  function test_RevealWithAuthorisation_AwardsPoints_WhenGameOver_DoesNotUpdateHighestScorers() public {
    Pixel8.Config memory config = _getDefaultPixel8Config();
    config.gameOverRevealThreshold = 1;
    config.linkedContracts.gameStats = gameStats_addr;
    pixel8 = new Pixel8(config);
    pixel8_addr = address(pixel8);
    
    _pixel8_mint_and_reveal(wallet1, 1, 1);

    assertEq(gameStats.highestPoints(pixel8_addr)[0], wallet1);
    assertEq(gameStats.points(pixel8_addr, wallet1), 50);

    assertEq(pixel8.gameOver(), true);

    _pixel8_mint_and_reveal(wallet2, 2, 2);

    assertEq(gameStats.highestPoints(pixel8_addr)[0], wallet1);

    assertEq(gameStats.points(pixel8_addr, wallet1), 50);
    assertEq(gameStats.points(pixel8_addr, wallet2), 0); // no points awarded because game is over
  }

  function test_RevealWithNotAuthorisation_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.reveal(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: 1,
      uri: "uri1",
      points: 50,
      authSig: _computeOwnerSig(
        abi.encodePacked(wallet1, uint(1), "uri1", uint(50)),
        block.timestamp + 10 seconds
      )
    }));

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, wallet1));
    pixel8.reveal(Pixel8.MintRevealParams({
      wallet: wallet1,
      tokenId: 1,
      uri: "uri1",
      points: 50,
      authSig: _computeSig(
        0x123,
        abi.encodePacked(wallet1, uint(1), "uri1", uint(50)),
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
      points: 50,
      authSig: _computeAuthoriserSig(
        abi.encodePacked(wallet1, uint(1), "uri", uint(50)),
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

  function test_GetTileState_BeforeReveal() public {
    Pixel8.TileState memory state = pixel8.getTileState(1);
    assertEq(state.revealed, false, "Tile should not be revealed initially");
    assertEq(state.imageUri, pixel8.defaultImage(), "Tile should have default image initially");
    assertEq(state.owner, wallet1, "Tile should be owned by wallet1");
  }

  function test_GetTileState_AfterReveal() public {
    vm.prank(wallet1);
    _pixel8_reveal(wallet1, 1, "uri1");

    Pixel8.TileState memory state = pixel8.getTileState(1);
    assertEq(state.revealed, true, "Tile should be revealed");
    assertEq(state.imageUri, "uri1", "Tile should have updated image URI");
    assertEq(state.owner, wallet1, "Tile should still be owned by wallet1");
  }
}
