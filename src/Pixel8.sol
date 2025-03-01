// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Auth } from "./Auth.sol";
import { ERC721 } from "./ERC721.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IERC165 } from "openzeppelin/interfaces/IERC165.sol";
import { IERC721 } from "openzeppelin/interfaces/IERC721.sol";
import { ERC2981 } from "openzeppelin/token/common/ERC2981.sol";
import { IERC4906 } from "openzeppelin/interfaces/IERC4906.sol";
import { Base64 } from "openzeppelin/utils/Base64.sol";
import { ERC165 } from "openzeppelin/utils/introspection/ERC165.sol";
import { LibErrors } from "./LibErrors.sol";
import { IPixel8 } from "./IPixel8.sol";
import { Base } from "./Base.sol";
import { IGameStats } from "./IGameStats.sol";


contract Pixel8 is Auth, ERC721, ERC2981, IERC4906, IPixel8, Base {
  /**
   * @dev The version of the contract.
   */
  uint public constant VERSION = 1;

  /**
   * @dev Emitted when the game is over.
   */
  event GameOver();

  /**
   * @dev Emitted when a force swap occurs.
   */
  event ForceSwapped(uint256 fromTokenId, uint256 toTokenId);

  /**
   * @dev Force-swap config.
   */
  struct ForceSwap {
    /** Cost in wei to perform a force swap */
    uint cost;
    /** Duration in seconds for the cooldown period between force swaps */
    uint cooldownPeriod;
  }


  /**
   * @dev Royalties config.
   */
  struct Royalties {
    /** The receiver of the royalties. */
    address receiver;
    /** The trading fee in bips. */
    uint96 feeBips;
  }

  /**
   * @dev Mint/reveal call parameters.
   */
  struct MintRevealParams {
    address wallet;
    uint256 tokenId;
    string uri;
    uint256 points;
    Auth.Signature authSig;
  }

  /** The prize pool fee in bips. */
  uint96 private prizePoolFeeBips;

  /**
   * @dev Dev royalties info.
   */
  Royalties private devRoyalties;

  /**
   * @dev Creator royalties info.
   */
  Royalties private creatorRoyalties;

  /**
   * @dev Prize pool final amount.
   */
  uint256 private prizePoolFinalAmount;

  /**
   * @dev Dev royalties final amount.
   */
  uint256 private devRoyaltiesFinalAmount;

  /**
   * @dev Creator royalties final amount.
   */
  uint256 private creatorRoyaltiesFinalAmount;

  /**
   * @dev The game stats contract.
   */
  IGameStats public gameStats;

  /**
   * @dev The authoriser can approve token reveals.
   */
  address public authoriser;

  /**
   * @dev Default token image as a data URI.
   */
  string public defaultImage;
  
  /**
   * @dev The number of tokens that have been revealed.
   */
  uint public numRevealed;

  /**
   * @dev The game is over once given on. of tiles have been revealed.
   */
  uint public gameOverRevealThreshold;

  /**
   * @dev Game over.
   */
  bool public gameOver;

  /**
   * @dev Mapping of revealed tokens.
   */
  mapping(uint256 => bool) public revealed;

  /**
   * @dev Per-token metadata.
   */
  mapping(uint256 => string) public tokenMetadata;

  /** 
   * @dev Whether the prize has been claimed for a given wallet.
   */
  mapping(address => bool) public prizeClaimed;

  /**
   * @dev When each token's last cooldown period started
   */
  mapping(uint256 => uint256) public lastCooldownStartTime;

  /**
   * @dev Force-swap config.
   */
  ForceSwap private forceSwapConfig;

  /**
   * @dev The number of tokens that need to be minted before external trading is enabled.
   */
  uint public externalTradeThreshold;

  /**
   * @dev Tile state.
   */
  struct TileState {
    bool revealed;
    string imageUri;
    uint256 lastCooldownStartTime;
    address owner;
  }

  // Constructor

  struct LinkedContractsConfig {
    /** Game stats contract */
    address gameStats;
    /** Pool address */
    address pool;
  }

  struct Config {
    /** Name of the contract */
    string name;
    /** Symbol of the contract */
    string symbol;
    /** Owner. */
    address owner;
    /** Authoriser. */
    address authoriser;
    /** Dev royalty receiver  */
    Royalties devRoyalty;
    /** Creator royalty receiver */
    Royalties creatorRoyalty;
    /** Force swap config */
    ForceSwap forceSwapConfig;
    /** Default token image as a data URI. */
    string defaultImage;
    /** Prize pool trading fee. */
    uint96 prizePoolFeeBips;
    /** Game over reveal threshold - the game has ended once the given on. of tiles have been revealed.*/
    uint gameOverRevealThreshold;
    /** Number of tokens that need to be minted before external trading is enabled */
    uint externalTradeThreshold;
    /** Linked contracts */
    LinkedContractsConfig linkedContracts;
  }
  
  /**
   * @dev Constructor.
   */
  constructor(Config memory _config) 
    ERC721(_config.name, _config.symbol) 
    Base(_config.linkedContracts.pool, _config.owner)
  {
    authoriser = _config.authoriser;
    defaultImage = _config.defaultImage;
    gameOverRevealThreshold = _config.gameOverRevealThreshold;

    devRoyalties.receiver = _config.devRoyalty.receiver;
    devRoyalties.feeBips = _config.devRoyalty.feeBips;
    creatorRoyalties.receiver = _config.creatorRoyalty.receiver;
    creatorRoyalties.feeBips = _config.creatorRoyalty.feeBips;
    forceSwapConfig = _config.forceSwapConfig;
    externalTradeThreshold = _config.externalTradeThreshold;
    gameStats = IGameStats(_config.linkedContracts.gameStats);
    prizePoolFeeBips = _config.prizePoolFeeBips;

    _setDefaultRoyalty(address(this), devRoyalties.feeBips + creatorRoyalties.feeBips + prizePoolFeeBips);
  }

  // Approvals

  /**
   * @dev See {IERC721-isApprovedForAll}.
   */
  function isApprovedForAll(address owner, address spender) public view override(ERC721, IERC721) returns (bool) {
    return (spender == address(this) || spender == pool || ERC721.isApprovedForAll(owner, spender));
  }

  /**
   * @dev Override to restrict transfers to pool and this contract only until external trade threshold is met
   */
  function _isAuthorized(address caller, address from, uint256 id) internal view virtual override returns (bool) {
    if (totalSupply < externalTradeThreshold) {
      return caller == pool || caller == address(this);
    }
    return super._isAuthorized(caller, from, id);
  }

  // Interface

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981, IERC165) returns (bool) {
    return type(IPixel8).interfaceId == interfaceId
      || ERC721.supportsInterface(interfaceId)
      || ERC2981.supportsInterface(interfaceId)
      || type(IERC4906).interfaceId == interfaceId
      || ERC165.supportsInterface(interfaceId);
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
              '"description": "An unrevealed Pixel8 tile - https://pixel8.fun",',
              '"image": "', defaultImage, '"',
          '}'
        ) 
      );

      return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }
  }

  // Functions - getters

  function getDevRoyaltyConfig() external view returns (Royalties memory) {
    return devRoyalties;
  }

  function getCreatorRoyaltyConfig() external view returns (Royalties memory) {
    return creatorRoyalties;
  }

  function getPrizePoolFeeBips() external view returns (uint96) {
    return prizePoolFeeBips;
  }

  function getForceSwapConfig() external view returns (ForceSwap memory) {
    return forceSwapConfig;
  }  

  function getTileState(uint256 tokenId) external view returns (TileState memory) {
    return TileState({
        revealed: revealed[tokenId],
        imageUri: revealed[tokenId] ? tokenMetadata[tokenId] : defaultImage,
        lastCooldownStartTime: lastCooldownStartTime[tokenId],
        owner: _ownerOf[tokenId]
    });
  }

  /**
   * @dev Royalties and prizes.
   */
  struct RoyaltiesPrizes {
    uint devRoyaltiesPot;
    uint creatorRoyaltiesPot;
    uint prizePoolPot;
  }

  function getRoyaltiesPrizes() public view returns (RoyaltiesPrizes memory prizes) {
    if (gameOver) {
      prizes.devRoyaltiesPot = devRoyaltiesFinalAmount;
      prizes.creatorRoyaltiesPot = creatorRoyaltiesFinalAmount;
      prizes.prizePoolPot = prizePoolFinalAmount;
    } else {
      uint totalBips = devRoyalties.feeBips + creatorRoyalties.feeBips + prizePoolFeeBips;
      prizes.devRoyaltiesPot = address(this).balance * devRoyalties.feeBips / totalBips;
      prizes.creatorRoyaltiesPot = address(this).balance * creatorRoyalties.feeBips / totalBips;
      prizes.prizePoolPot = address(this).balance - prizes.devRoyaltiesPot - prizes.creatorRoyaltiesPot;
    }
  }

  // Functions - reveal token

  /**
   * @dev Reveal tokens.
   *
   * @param _params The reveal parameters.
   */
  function reveal(MintRevealParams calldata _params) external {
    _assertValidSignature(msg.sender, authoriser, _params.authSig, abi.encodePacked(_params.wallet, _params.tokenId, _params.uri, _params.points));

    _requireOwned(_params.tokenId);

    _reveal(_params);
  }

  /**
   * @dev Helper method for revealing a token.
   *
   * @param _params The reveal parameters.
   */
  function _reveal(MintRevealParams memory _params) private {
    if (revealed[_params.tokenId]) {
      revert LibErrors.AlreadyRevealed(_params.tokenId);
    }

    _setTokenMetadata(_params.tokenId, _params.uri);

    revealed[_params.tokenId] = true;

    if (!gameOver) {  
      gameStats.addRevealPoints(_params.wallet, _params.points);
    }

    numRevealed++;
    if (numRevealed >= gameOverRevealThreshold && !gameOver) {
      _setGameOver();
    }
  }

  function _setTokenMetadata(uint256 _id, string memory _uri) private {
    tokenMetadata[_id] = _uri;
    // IERC4906
    emit MetadataUpdate(_id);
  }

  // Authoriser

  /**
   * @dev Set the authoriser.
   * @param _authoriser The address of the new authoriser.
   */
  function setAuthoriser(address _authoriser) external onlyOwner {
    authoriser = _authoriser;
  }

  // Functions needed by the pool 

  /**
   * @dev See {IPixel8-getRoyaltyInfo}.
   */
  function getRoyaltyInfo() external view override returns (address receiver, uint256 feeBips) {
    /* will cancel out fee denomination divisor so that we get back the bips */
    (receiver, feeBips) = royaltyInfo(1, _feeDenominator());
  }

  /**
   * @dev See {IPixel8-batchMint}.
   */
  function batchMint(address _to, uint _startId, uint _count) external override onlyPool {
    _safeBatchMint(_to, _startId, _count, "");
    _updateLastCooldownStartTimeRange(_startId, _count);
  }

  /**
   * @dev See {IPixel8-batchTransferIds}.
   */
  function batchTransferIds(address _from, address _to, uint[] calldata _tokenIds) external override {
    _safeBatchTransfer(msg.sender, _from, _to, _tokenIds, "");
    if (_from == pool) {
      _updateLastCooldownStartTimeIds(_tokenIds);
    }
  }

  /**
    * @dev See {IPixel8-batchTransferRange}.
    */
  function batchTransferRange(address _from, address _to, uint _numTokens) external override {
    uint256 firstTransferredId = _safeBatchTransfer(msg.sender, _from, _to, _numTokens, "");
    if (_from == pool) {
      _updateLastCooldownStartTimeRange(firstTransferredId, _numTokens);
    }
  }

  /**
   * @dev Force swap a token with another token
   * @param fromTokenId The token ID owned by from address
   * @param toTokenId The token ID to swap with
   */
  function forceSwap(uint256 fromTokenId, uint256 toTokenId) external payable {
    address from = msg.sender;
    
    // Check that game is not over
    if (gameOver) {
      revert LibErrors.GameOver();
    }

    // Check that msg.value is sufficient
    if (msg.value < forceSwapConfig.cost) {
      revert LibErrors.InsufficientSenderFunds(from, forceSwapConfig.cost, msg.value);
    }

    // Check that fromTokenId is owned by from
    if (ownerOf(fromTokenId) != from) {
      revert LibErrors.Unauthorized(from);
    }

    // Check that tokens are different
    if (fromTokenId == toTokenId) {
      revert LibErrors.InvalidTokenId(toTokenId);
    }

    // Check that toTokenId exists
    address toOwner = ownerOf(toTokenId);

    // Check that toTokenId is not owned by pool
    if (toOwner == pool) {
      revert LibErrors.TokenOwnedByPool(toTokenId);
    }

    // Check cooldown period
    if (block.timestamp - lastCooldownStartTime[toTokenId] < forceSwapConfig.cooldownPeriod) {
      revert LibErrors.TokenOnCooldown(toTokenId);
    }

    if (block.timestamp - lastCooldownStartTime[fromTokenId] < forceSwapConfig.cooldownPeriod) {
      revert LibErrors.TokenOnCooldown(fromTokenId);
    }

    // Perform the swap
    _transfer(address(this), from, toOwner, fromTokenId);
    _transfer(address(this), toOwner, from, toTokenId);

    // Reset cooldown times for both tokens
    lastCooldownStartTime[fromTokenId] = block.timestamp;
    lastCooldownStartTime[toTokenId] = block.timestamp;

    // Update force swap stats
    gameStats.recordForceSwap(from);

    emit ForceSwapped(fromTokenId, toTokenId);
  }

  function claimPrize(address _wallet) external {
    if (!gameOver) {
      revert LibErrors.GameNotOver();
    }

    if (prizeClaimed[_wallet]) {
      revert LibErrors.PrizeAlreadyClaimed(_wallet);
    }

    prizeClaimed[_wallet] = true;

    RoyaltiesPrizes memory prizes = getRoyaltiesPrizes();

    uint prize = gameStats.calculatePrize(address(this), prizes.prizePoolPot, _wallet);

    payable(_wallet).transfer(prize);
  }

  // Private methods

  /**
   * @dev Game over.
   */
  function _setGameOver() private {
    RoyaltiesPrizes memory prizes = getRoyaltiesPrizes();
    devRoyaltiesFinalAmount = prizes.devRoyaltiesPot;
    creatorRoyaltiesFinalAmount = prizes.creatorRoyaltiesPot;
    prizePoolFinalAmount = prizes.prizePoolPot;

    // do this after getting latest prizes / royalties so that the 
    // calculation above is correct.
    gameOver = true;

    // update royalty fee to just be the dev fee and also send all money to the dev receiver
    _setDefaultRoyalty(devRoyalties.receiver, devRoyalties.feeBips);

    // withdraw dev and creator royalties so far
    payable(devRoyalties.receiver).transfer(devRoyaltiesFinalAmount);
    payable(creatorRoyalties.receiver).transfer(creatorRoyaltiesFinalAmount);

    // Tell game stats contract that game is over
    gameStats.setGameOver();

    emit GameOver();
  }



  /**
   * @dev Updates lastCooldownStartTime for a range of token IDs.
   * @param _startId The starting token ID
   * @param _count The number of consecutive tokens
   */
  function _updateLastCooldownStartTimeRange(uint256 _startId, uint256 _count) private {
    for (uint i = 0; i < _count; i++) {
      lastCooldownStartTime[_startId + i] = block.timestamp;
    }
  }

  /**
   * @dev Updates lastCooldownStartTime for specific token IDs.
   * @param _tokenIds Array of token IDs to update
   */
  function _updateLastCooldownStartTimeIds(uint256[] calldata _tokenIds) private {
    for (uint i = 0; i < _tokenIds.length; i++) {
      lastCooldownStartTime[_tokenIds[i]] = block.timestamp;
    }
  }  


  // Modifiers

  /**
   * @dev Enable this contract to receive ether.
   */
  receive() external payable {}  
}
