// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Auth } from "./Auth.sol";
import { ERC721 } from "./ERC721.sol";
import { IERC165 } from "openzeppelin/interfaces/IERC165.sol";
import { IERC721 } from "openzeppelin/interfaces/IERC721.sol";
import { ERC2981 } from "openzeppelin/token/common/ERC2981.sol";
import { IERC4906 } from "openzeppelin/interfaces/IERC4906.sol";
import { Base64 } from "openzeppelin/utils/Base64.sol";
import { Strings } from "openzeppelin/utils/Strings.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "./LibErrors.sol";
import { IPuzzArt } from "./IPuzzArt.sol";
import { ILotteryNFT } from "./ILotteryNFT.sol";
import { BlastOwnable } from "./BlastOwnable.sol";


contract PuzzArt is Auth, ERC721, ERC2981, IERC4906, IPuzzArt, BlastOwnable {
  using Strings for uint256;

  /**
   * @dev Lottery info.
   */
  struct Lottery {
    /** The winners of the lottery. */
    uint[] winners;
    /** No. of winning tickets - to be set ahead of time. */
    uint numWinningTickets;
    /** The final drawn pot. */
    uint drawnPot;
    /** Whether the lottery has been drawn. */
    bool drawn;
    /** The deadline for the lottery. */
    uint deadline;
    /** The number of tiles that need to be revealed before the lottery can be drawn. */
    uint tileRevealThreshold;
    /** The trading fee for the lottery. */
    uint96 feeBips;
    /** The NFT contract for the lottery tickets. */
    ILotteryNFT nft;
  }

  /**
   * @dev Dev royalties info.
   */
  struct DevRoyalties {
    /** The receiver of the dev royalties. */
    address receiver;
    /** The trading fee for the dev royalties. */
    uint96 feeBips;
  }

  /**
   * @dev Mint/reveal call parameters.
   */
  struct MintRevealParams {
    address wallet;
    uint256 tokenId;
    string uri;
    uint256 lotteryTickets;
    Auth.Signature authSig;
  }

  /**
   * @dev Lottery info.
   */
  Lottery private lottery;

  /** 
   * @dev Mapping of lottery winnings claimed (ticket => claimed or not).
   */
  mapping(uint => bool) public lotteryWinningsClaimed;

  /**
   * @dev Dev royalties info.
   */
  DevRoyalties private devRoyalties;

  /**
   * @dev The pool contract.
   */
  address public pool;

  /**
   * @dev The minter can approve new token mints and token reveals.
   */
  address public minter;

  /**
   * @dev Default token image as a data URI.
   */
  string public defaultImage;
  
  /**
   * @dev The number of tokens that have been revealed.
   */
  uint public numRevealed;

  /**
   * @dev Mapping of revealed tokens.
   */
  mapping(uint256 => bool) public revealed;

  /**
   * @dev Per-token metadata.
   */
  mapping(uint256 => string) public tokenMetadata;

  // Constructor

  /**
   * @dev Configuration parameters for constructor.
   */
  struct Config {
    /** Owner. */
    address owner;
    /** Minter. */
    address minter;
    /** Dev royalty receiver  */
    address devRoyaltyReceiver;
    /** Dev royalty fee */
    uint96 devRoyaltyFeeBips;
    /** Default token image as a data URI. */
    string defaultImage;
    /** Lottery trading fee. */
    uint96 lotteryPotFeeBips;
    /** Lottery deadline. */
    uint lotteryDeadline;
    /** Lottery reveal threshold - the lottery can be drawn once given on. of tiles have been revealed.*/
    uint lotteryRevealThreshold;
  }
  
  /**
   * @dev Constructor.
   */
  constructor(Config memory _config) ERC721("PuzzArt", "PUZZART") BlastOwnable(_config.owner) {
    minter = _config.minter;
    defaultImage = _config.defaultImage;

    lottery.feeBips = _config.lotteryPotFeeBips;
    lottery.deadline = _config.lotteryDeadline;
    lottery.tileRevealThreshold = _config.lotteryRevealThreshold;

    devRoyalties.receiver = _config.devRoyaltyReceiver;
    devRoyalties.feeBips = _config.devRoyaltyFeeBips;

    _setDefaultRoyalty(address(this), devRoyalties.feeBips + lottery.feeBips);
  }

  // Approvals

  /**
   * @dev See {IERC721-isApprovedForAll}.
   */
  function isApprovedForAll(address owner, address spender) public view override(ERC721, IERC721) returns (bool) {
    return (spender == pool || ERC721.isApprovedForAll(owner, spender));
  }

  // Interface

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981, IERC165) returns (bool) {
    return ERC721.supportsInterface(interfaceId)
      || ERC2981.supportsInterface(interfaceId)
      || type(IERC4906).interfaceId == interfaceId;
  }

  // token URI

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireOwned(tokenId);

    if (bytes(tokenMetadata[tokenId]).length > 0) {
      return tokenMetadata[tokenId];
    } else {
      string memory json = string(
        abi.encodePacked(
          '{',
              '"name": "Unrevealed tile",',
              '"description": "An unrevealed PuzzArt tile - see https://puzz.art for more info.",',
              '"image": "', defaultImage, '"',
          '}'
        ) 
      );

      return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }
  }

  // Functions - reveal token

  /**
   * @dev Reveal tokens.
   *
   * @param _params The reveal parameters.
   */
  function reveal(MintRevealParams calldata _params) external {
    _assertValidSignature(msg.sender, minter, _params.authSig, abi.encodePacked(_params.wallet, _params.tokenId, _params.uri, _params.lotteryTickets));

    _requireOwned(_params.tokenId);

    _reveal(_params.tokenId, _params.uri);

    if (_params.lotteryTickets > 0) {
      lottery.nft.batchMint(_params.wallet, _params.lotteryTickets);
    }
  }

  /**
   * @dev Helper method for revealing a token.
   *
   * @param _id The token id.
   * @param _uri The token URI to set.
   */
  function _reveal(uint256 _id, string memory _uri) internal {
    if (revealed[_id]) {
      revert LibErrors.AlreadyRevealed(_id);
    }

    revealed[_id] = true;
    numRevealed++;

    _setTokenMetadata(_id, _uri);
  }

  function _setTokenMetadata(uint256 _id, string memory _uri) internal {
    tokenMetadata[_id] = _uri;
    // IERC4906
    emit MetadataUpdate(_id);
  }

  // Functions - set default image

  /**
   * @dev Set the default token image.
   * @param _defaultImage The new default image.
   */
  function setDefaultImage(string calldata _defaultImage) external onlyOwner {
    defaultImage = _defaultImage;
    
    // IERC4906
    emit BatchMetadataUpdate(1, totalSupply);
  }

  // Functions - set pool

  /**
   * @dev Set the pool.
   * @param _pool The address of the new pool.
   */
  function setPool(address _pool) external onlyOwner {
    pool = _pool;
  }

  // Minting

  /**
   * @dev Set the minter.
   * @param _minter The address of the new minter.
   */
  function setMinter(address _minter) external onlyOwner {
    minter = _minter;
  }

  /**
   * @dev Mint and optionally reveal a token, authorized by the minter.
   *
   * @param _params The reveal parameters.
   */
  function mint(MintRevealParams calldata _params) external {
    _assertValidSignature(msg.sender, minter, _params.authSig, abi.encodePacked(_params.wallet, _params.tokenId, _params.uri, _params.lotteryTickets));

    _safeMint(_params.wallet, _params.tokenId, "");

    if (bytes(_params.uri).length > 0) {
      _reveal(_params.tokenId, _params.uri);
    }

    if (_params.lotteryTickets > 0) {
      lottery.nft.batchMint(_params.wallet, _params.lotteryTickets);
    }
  }

  // Pool functions 

  /**
   * @dev See {IPoolNFT-getRoyaltyInfo}.
   */
  function getRoyaltyInfo() external view override returns (address receiver, uint256 feeBips) {
    /* will cancel out fee denomination divisor so that we get back the bips */
    (receiver, feeBips) = royaltyInfo(1, _feeDenominator());
  }

  /**
   * @dev See {IPoolNFT-batchMint}.
   */
  function batchMint(address _to, uint _startId, uint _count) external override onlyPool {
    _safeBatchMint(_to, _startId, _count, "");
  }

  /**
   * @dev See {IPoolNFT-batchTransferIds}.
   */
  function batchTransferIds(address _from, address _to, uint[] calldata _tokenIds) external override {
    _safeBatchTransfer(msg.sender, _from, _to, _tokenIds, "");
  }

  /**
    * @dev See {IPoolNFT-batchTransferRange}.
    */
  function batchTransferRange(address _from, address _to, uint _numTokens) external override {
    _safeBatchTransfer(msg.sender, _from, _to, _numTokens, "");
  }

  // dev royalties

  function getDevRoyalties() external view returns (DevRoyalties memory) {
    return devRoyalties;
  }

  // lottery

  /**
   * @dev Get the lottery info.
   */
  function getLottery() external view returns (Lottery memory) {
    return lottery;
  }


  /**
   * @dev Calculate the dev royalties and lottery pots so far based on the current contract balance.
   */
  function _calculatePots() internal view returns (uint devRoyaltiesPot, uint lotteryPot) {
    uint totalBips = devRoyalties.feeBips + lottery.feeBips;
    devRoyaltiesPot = address(this).balance * devRoyalties.feeBips / totalBips;
    lotteryPot = address(this).balance - devRoyaltiesPot;
  }


  /**
   * @dev Get the lottery.
   *
   * If the lottery hasn't been drawn yet, this will calculate the potential pot. 
   * If the lottery has been drawn, this will return the actual pot.
   */
  function getLotteryPot() external view returns (uint) {
    if (lottery.drawn) {
      return lottery.drawnPot;
    } else {
      (, uint lotteryPot) = _calculatePots();
      return lotteryPot;
    }
  }


  /**
   * @dev Set the lottery NFT contract.
   * 
   * Requirements:
   * - The caller must be the owner.
   * - The lottery NFT contract must not have been set yet.
   * - The lottery NFT contract must support the ILotteryNFT interface.
   * 
   * @param _nft The address of the new lottery NFT contract.
   */
  function setLotteryNFT(address _nft) external onlyOwner {
    if (address(lottery.nft) != address(0)) {
      revert LibErrors.LotteryNFTAlreadySet();
    }
    
    if (!IERC165(_nft).supportsInterface(type(ILotteryNFT).interfaceId)) {
      revert LibErrors.LotteryNFTInvalid();
    }

    lottery.nft = ILotteryNFT(_nft);
  }

  /**
   * @dev Check if the lottery can be drawn.
   */
  function canDrawLottery() external view returns (bool) {
    return !lottery.drawn && 0 < lottery.numWinningTickets && (block.timestamp >= lottery.deadline || numRevealed >= lottery.tileRevealThreshold);
  }

  /**
   * @dev Set the no. of winning tickets for the lottery.
   *
   * This can only be called once. Subsequent calls to drawLottery() must have the exactly this no. of tickets.
   */
  function setLotteryNumWinningTickets(uint _num) external onlyOwner {
    if (_num < 1) {
      revert LibErrors.LotteryInvalidNumWinningTickets();
    }

    if (lottery.numWinningTickets > 0) {
      revert LibErrors.LotteryNumWinningTicketsAlreadySet();
    }

    lottery.numWinningTickets = _num;
  }

  /**
   * @dev Draw the lottery.
   *
   * @param _winners The winning ticket numbers.
   */
  function drawLottery(uint[] calldata _winners) external onlyOwner {
    if (lottery.drawn) {
      revert LibErrors.LotteryAlreadyDrawn();
    }

    if (block.timestamp < lottery.deadline && numRevealed < lottery.tileRevealThreshold) {
      revert LibErrors.LotteryCannotBeDrawnYet();
    }

    if (lottery.numWinningTickets != _winners.length) {
      revert LibErrors.LotteryNumWinningTicketsNotSet();
    }

    lottery.drawn = true;

    (uint devRoyaltiesPot, uint lotteryPot) = _calculatePots();
    lottery.drawnPot = lotteryPot;

    // update royalty fee to just be the dev fee and also send all money to the dev receiver
    _setDefaultRoyalty(devRoyalties.receiver, devRoyalties.feeBips);

    // generate winners
    lottery.winners = _winners;

    // withdraw dev royalties so far
    payable(devRoyalties.receiver).transfer(devRoyaltiesPot);
  }

  /**
   * @dev Check if a given ticket is a lottery winner.
   *
   * @param _ticket The ticket number to check.
   */
  function isLotteryWinner(uint _ticket) public view returns (bool) {
    // check that the lottery has been drawn
    if (!lottery.drawn) {
      return false;
    }

    for (uint i = 0; i < lottery.winners.length; i++) {
      if (lottery.winners[i] == _ticket) {
        return true;
      }
    }

    return false;
  }

  /**
   * @dev Check if a given ticket can claim lottery winnings.
   *
   * @param _ticket The ticket number to check.
   */
  function canClaimLotteryWinnings(uint _ticket) public view returns (bool) {
    if (!isLotteryWinner(_ticket)) {
      return false;
    }
    return !lotteryWinningsClaimed[_ticket];
  }


  /**
   * @dev Claim lottery winnings for a given ticket.
   *
   * @param _ticket The ticket number to claim winnings for.
   */
  function claimLotteryWinnings(uint _ticket) external {
    if (!canClaimLotteryWinnings(_ticket)) {
      revert LibErrors.LotteryCannotClaimWinnings(_ticket);
    }

    lotteryWinningsClaimed[_ticket] = true;

    // send winnings
    address wallet = lottery.nft.ownerOf(_ticket);
    payable(wallet).transfer(lottery.drawnPot / lottery.winners.length);
  }

  // Modifiers

  /**
   * @dev Only the pool can call this function.
   */
  modifier onlyPool() {
    if (_msgSender() != pool) {
      revert LibErrors.Unauthorized(_msgSender());
    }
    _;
  }

  /**
   * @dev Enable this contract to receive ether.
   */
  receive() external payable {}  
}
