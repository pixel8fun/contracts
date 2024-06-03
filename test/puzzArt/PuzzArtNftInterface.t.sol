// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { IERC165 } from "openzeppelin/interfaces/IERC165.sol";
import { IERC721 } from "openzeppelin/interfaces/IERC721.sol";
import { IERC721Metadata } from "openzeppelin/interfaces/IERC721Metadata.sol";
import { IERC721Enumerable } from "openzeppelin/interfaces/IERC721Enumerable.sol";
import { IERC2981 } from "openzeppelin/interfaces/IERC2981.sol";
import { IERC4906 } from "openzeppelin/interfaces/IERC4906.sol";

contract PuzzArtNftInterface is PuzzArtNftTestBase {
  function test_SupportsInterfaces() public {
    // Test that the contract supports the ERC165 interface
    assertEq(puzzArt.supportsInterface(type(IERC165).interfaceId), true, "erc165");
    // Test that the contract supports the ERC721 interface
    assertEq(puzzArt.supportsInterface(type(IERC721).interfaceId), true, "erc721");
    // Test that the contract supports the ERC721Metadata interface
    assertEq(puzzArt.supportsInterface(type(IERC721Metadata).interfaceId), true, "erc721metadata");
    // Test that the contract supports the ERC721Enumerable interface
    assertEq(puzzArt.supportsInterface(type(IERC721Enumerable).interfaceId), true, "erc721enumerable");
    // Test that the contract supports the ERC721Royalty interface
    assertEq(puzzArt.supportsInterface(type(IERC2981).interfaceId), true, "erc2981");
    // Test that the contract supports the ERC721Royalty interface
    assertEq(puzzArt.supportsInterface(type(IERC4906).interfaceId), true, "erc4906");
  }
}