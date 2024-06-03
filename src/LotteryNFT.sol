// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { ERC721 } from "./ERC721.sol";
import { ERC2981 } from "openzeppelin/token/common/ERC2981.sol";
import { IERC165 } from "openzeppelin/interfaces/IERC165.sol";
import { Base64 } from "openzeppelin/utils/Base64.sol";
import { LibErrors } from "./LibErrors.sol";
import { ILotteryNFT } from "./ILotteryNFT.sol";
import { BlastOwnable } from "./BlastOwnable.sol";

contract LotteryNFT is ERC721, ERC2981, ILotteryNFT, BlastOwnable {
  /**
   * @dev Minter.
   */
  address public minter;

  /**
   * @dev Default token image as a data URI.
   */
  string public defaultImage;

  /**
   * @dev Configuration parameters for constructor.
   */
  struct Config {
    /** Owner. */
    address owner;
    /** Minter. */
    address minter;
    /** Default token image as a data URI. */
    string defaultImage;
    /** Royalty receiver. */
    address royaltyReceiver;
    /** Royalty fee. */
    uint96 royaltyFeeBips;
  }
  
  /**
   * @dev Constructor.
   */
  constructor(Config memory _config) ERC721("PuzzArt Lottery", "PUZZART_LOTTERY") BlastOwnable(_config.owner) {
    minter = _config.minter;
    defaultImage = _config.defaultImage;
    _setDefaultRoyalty(_config.royaltyReceiver, _config.royaltyFeeBips);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981, IERC165) returns (bool) {
    return ERC721.supportsInterface(interfaceId)
      || ERC2981.supportsInterface(interfaceId)
      || type(ILotteryNFT).interfaceId == interfaceId;
  }


  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireOwned(tokenId);

    string memory json = string(
      abi.encodePacked(
        '{',
            '"name": "Lottery ticket",',
            '"description": "A lottery ticket for the PuzzArt NFT collection - see https://puzz.art for more info.",',
            '"image": "', defaultImage, '"',
        '}'
      ) 
    );

    return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
  }  

  /**
   * See {ILotteryNFT-batchMint}.
   */
  function batchMint(address _to, uint256 _count) external override onlyMinter {
    _safeBatchMint(_to, totalSupply + 1 ,_count, "");
  }  

  // Modifiers

  /**
   * @dev Only the pool can call this function.
   */
  modifier onlyMinter() {
    if (msg.sender != minter) {
      revert LibErrors.Unauthorized(msg.sender);
    }
    _;
  }  
}