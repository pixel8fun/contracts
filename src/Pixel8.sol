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
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "./LibErrors.sol";
import { IPixel8 } from "./IPixel8.sol";


contract Pixel8 is Ownable, Auth, ERC721, ERC2981, IERC4906, IPixel8 {
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
   * @dev Emitted when the pool is set.
   */
  event PoolSet(address pool);

  /**
   * @dev Emitted when a trade is recorded.
   */
  event TradeRecorded(address wallet, uint amount, bool buyOrSell, uint numItems);

  /**
   * @dev Prize pool info.
   */
  struct PrizePool {
    /** The final pot. */
    uint pot;
    /** The trading fee for the prize pool. */
    uint96 feeBips;
  }

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
   * @dev Royalties.
   */
  struct Royalties {
    /** The receiver of the royalties. */
    address receiver;
    /** The trading fee in bips. */
    uint96 feeBips;
    /** The final amount of royalties when game is over. */
    uint amount;
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

  /**
   * @dev Dev royalties info.
   */
  Royalties private devRoyalties;

  /**
   * @dev Creator royalties info.
   */
  Royalties private creatorRoyalties;

  /**
   * @dev Prize pool info.
   */
  PrizePool private prizePool;

  /**
   * @dev The liquidity pool contract.
   */
  address public pool;

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
   * @dev Game points for each wallet.
   */
  mapping(address => uint) public points;
  /**
   * @dev The wallets with the highest points.
   */
  address[3] public highestPoints;

  /**
   * @dev The number of force swaps for each wallet.
   */
  mapping(address => uint) public numForceSwaps;
  /**
   * @dev The wallet with the highest number of force swaps.
   */
  address public highestNumForceSwaps;

  /**
   * @dev Force-swap config.
   */
  ForceSwap public forceSwapConfig;

  /**
   * @dev The trading volume for each wallet.
   */
  mapping(address => uint) public tradingVolume;
  /**
   * @dev The wallet with the highest number of force swaps.
   */
  address public highestTradingVolume;

  /**
   * @dev The number of tokens that need to be minted before external trading is enabled.
   */
  uint public externalTradeThreshold;

  struct TileState {
    bool revealed;
    string imageUri;
    uint256 lastCooldownStartTime;
    address owner;
  }

  // Constructor

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
    /** Default token image as a data URI. */
    string defaultImage;
    /** Prize pool trading fee. */
    uint96 prizePoolFeeBips;
    /** Game over reveal threshold - the game has ended once the given on. of tiles have been revealed.*/
    uint gameOverRevealThreshold;
    /** Force swap config */
    ForceSwap forceSwapConfig;
    /** Number of tokens that need to be minted before external trading is enabled */
    uint externalTradeThreshold;
  }
  
  /**
   * @dev Constructor.
   */
  constructor(Config memory _config) ERC721(_config.name, _config.symbol) Ownable(_config.owner) {
    authoriser = _config.authoriser;
    defaultImage = _config.defaultImage;

    prizePool.feeBips = _config.prizePoolFeeBips;
    gameOverRevealThreshold = _config.gameOverRevealThreshold;

    devRoyalties.receiver = _config.devRoyalty.receiver;
    devRoyalties.feeBips = _config.devRoyalty.feeBips;
    creatorRoyalties.receiver = _config.creatorRoyalty.receiver;
    creatorRoyalties.feeBips = _config.creatorRoyalty.feeBips;
    forceSwapConfig = _config.forceSwapConfig;
    externalTradeThreshold = _config.externalTradeThreshold;

    _setDefaultRoyalty(address(this), devRoyalties.feeBips + creatorRoyalties.feeBips + prizePool.feeBips);
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
    return ERC721.supportsInterface(interfaceId)
      || ERC2981.supportsInterface(interfaceId)
      || type(IERC4906).interfaceId == interfaceId;
  }

  // Pool

  /**
   * @dev Set the pool address.
   */
  function setPool(address newPool) external onlyOwner {
    if (pool != address(0)) {
      revert LibErrors.PoolAlreadySet();
    }
    if (newPool == address(0)) {
      revert LibErrors.InvalidAddress(newPool);
    }
    pool = newPool;
    emit PoolSet(newPool);
  }


  function recordTrade(address _wallet, uint _amount, bool _buyOrSell, uint _numItems) external override onlyPool {
    tradingVolume[_wallet] += _amount;
    if (tradingVolume[_wallet] > tradingVolume[highestTradingVolume]) {
      highestTradingVolume = _wallet;
    }
    emit TradeRecorded(_wallet, _amount, _buyOrSell, _numItems);
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

  function getDevRoyalties() external view returns (Royalties memory) {
    return devRoyalties;
  }

  function getCreatorRoyalties() external view returns (Royalties memory) {
    return creatorRoyalties;
  }

  function getPrizePool() external view returns (PrizePool memory) {
    return prizePool;
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

  // Functions - reveal token

  /**
   * @dev Reveal tokens.
   *
   * @param _params The reveal parameters.
   */
  function reveal(MintRevealParams calldata _params) external {
    _assertValidSignature(msg.sender, authoriser, _params.authSig, abi.encodePacked(_params.wallet, _params.tokenId, _params.uri, _params.points));

    _requireOwned(_params.tokenId);

    _reveal(_params.tokenId, _params.uri);

    _addPlayerPoints(_params.wallet, _params.points);
  }

  /**
   * @dev Helper method for revealing a token.
   *
   * @param _id The token id.
   * @param _uri The token URI to set.
   */
  function _reveal(uint256 _id, string memory _uri) private {
    if (revealed[_id]) {
      revert LibErrors.AlreadyRevealed(_id);
    }

    _setTokenMetadata(_id, _uri);

    revealed[_id] = true;

    numRevealed++;
    if (numRevealed >= gameOverRevealThreshold) {
      _setGameOver();
    }
  }

  function _setTokenMetadata(uint256 _id, string memory _uri) private {
    tokenMetadata[_id] = _uri;
    // IERC4906
    emit MetadataUpdate(_id);
  }

  // Functions - set default image

  // Authoriser

  /**
   * @dev Set the authoriser.
   * @param _authoriser The address of the new authoriser.
   */
  function setAuthoriser(address _authoriser) external onlyOwner {
    authoriser = _authoriser;
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
    _updateLastCooldownStartTimeRange(_startId, _count);
  }

  /**
   * @dev See {IPoolNFT-batchTransferIds}.
   */
  function batchTransferIds(address _from, address _to, uint[] calldata _tokenIds) external override {
    _safeBatchTransfer(msg.sender, _from, _to, _tokenIds, "");
    if (_from == pool) {
      _updateLastCooldownStartTimeIds(_tokenIds);
    }
  }

  /**
    * @dev See {IPoolNFT-batchTransferRange}.
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
    numForceSwaps[from]++;
    if (numForceSwaps[from] > numForceSwaps[highestNumForceSwaps]) {
      highestNumForceSwaps = from;
    }

    emit ForceSwapped(fromTokenId, toTokenId);
  }

  // other

  struct PrizesRoyaltiesWinners {
    uint prizePoolPot;
    uint devRoyaltiesPot;
    uint creatorRoyaltiesPot;
    address biggestThief;
    uint biggestThiefPoints;
    address biggestTrader;
    uint biggestTraderVolume;
    address[3] highestScorers;
    uint[3] highestScores;
  }

  /**
   * @dev Get the prizes, royalties and winners.
   */
  function getPrizesRoyaltiesWinners() external view returns (PrizesRoyaltiesWinners memory) {
    uint[3] memory highestScores;
    for (uint i = 0; i < 3; i++) {
      highestScores[i] = points[highestPoints[i]];
    }

    uint devRoyaltiesPot = 0;
    uint creatorRoyaltiesPot = 0;
    uint prizePoolPot = 0;
    
    if (gameOver) {
      prizePoolPot = prizePool.pot;
      devRoyaltiesPot = devRoyalties.amount;
      creatorRoyaltiesPot = creatorRoyalties.amount;
    } else {
      (devRoyaltiesPot, creatorRoyaltiesPot, prizePoolPot) = _calculatePots();
    }

    return PrizesRoyaltiesWinners({
      prizePoolPot: prizePoolPot,
      devRoyaltiesPot: devRoyaltiesPot,
      creatorRoyaltiesPot: creatorRoyaltiesPot,
      biggestThief: highestNumForceSwaps,
      biggestThiefPoints: numForceSwaps[highestNumForceSwaps],
      biggestTrader: highestTradingVolume,
      biggestTraderVolume: tradingVolume[highestTradingVolume],
      highestScorers: highestPoints,
      highestScores: highestScores
    });
  }

  /**
   * @dev Game over.
   */
  function _setGameOver() private {
    gameOver = true;

    (uint devRoyaltiesPot, uint creatorRoyaltiesPot, uint prizePoolPot) = _calculatePots();
    prizePool.pot = prizePoolPot;
    devRoyalties.amount = devRoyaltiesPot;
    creatorRoyalties.amount = creatorRoyaltiesPot;

    // update royalty fee to just be the dev fee and also send all money to the dev receiver
    _setDefaultRoyalty(devRoyalties.receiver, devRoyalties.feeBips);

    // withdraw dev and creator royalties so far
    payable(devRoyalties.receiver).transfer(devRoyaltiesPot);
    payable(creatorRoyalties.receiver).transfer(creatorRoyaltiesPot);

    emit GameOver();
  }

  /**
   * @dev Check how much prize money given wallet can claim.
   *
   * @param _wallet The wallet to check.
   */
  function calculatePrize(address _wallet) public view returns (uint) {
    if (!gameOver) {
      return 0;
    }
    
    uint prize = 0;

    if (highestNumForceSwaps == _wallet) {
      prize += prizePool.pot * 100 / 1000; // 10%
    }
    
    if (highestTradingVolume == _wallet) {
      prize += prizePool.pot * 100 / 1000; // 10%
    }

    for (uint i = 0; i < highestPoints.length; i++) {
      if (highestPoints[i] == _wallet) {
        if (i == 0) {
          prize += prizePool.pot * 450 / 1000; // 45%
        } else if (i == 1) {
          prize += prizePool.pot * 250 / 1000; // 25%
        } else if (i == 2) {
          prize += prizePool.pot * 100 / 1000; // 10%
        }
      }
    }

    return prize;
  }


  /**
   * @dev Claim prize money for given wallet.
   *
   * @param _wallet The wallet to claim for.
   */
  function claimPrize(address _wallet) external {
    if (prizeClaimed[_wallet]) {
      revert LibErrors.PrizeAlreadyClaimed(_wallet);
    }

    prizeClaimed[_wallet] = true;

    payable(_wallet).transfer(calculatePrize(_wallet));
  }


  /**
   * @dev Calculate the dev royalties and prize pool pots so far based on the current contract balance.
   */
  function _calculatePots() private view returns (uint devRoyaltiesPot, uint creatorRoyaltiesPot, uint prizePoolPot) {
    uint totalBips = devRoyalties.feeBips + creatorRoyalties.feeBips + prizePool.feeBips;
    devRoyaltiesPot = address(this).balance * devRoyalties.feeBips / totalBips;
    creatorRoyaltiesPot = address(this).balance * creatorRoyalties.feeBips / totalBips;
    prizePoolPot = address(this).balance - devRoyaltiesPot - creatorRoyaltiesPot;
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

  function _addPlayerPoints(address _wallet, uint _points) private {
    points[_wallet] += _points;

    // update highest points list

    // first go through list and see if wallet is already a high scorer
    uint i = 0;
    while (i < 3) {
      if (highestPoints[i] == _wallet) {
        break;
      }
      i++;
    }

    // if not in list but it should be, then add it
    if (i == 3 && points[highestPoints[2]] < points[_wallet]) {
      highestPoints[2] = _wallet;
      i = 2;
    }

    // now check if it should be in the second position
    if (i == 2 && points[highestPoints[1]] < points[_wallet]) {
        address temp = highestPoints[1];
        highestPoints[1] = highestPoints[2];
        highestPoints[2] = temp;
        i = 1;
    } 
    
    // now check if it should be in the first position
    if (i == 1 && points[highestPoints[0]] < points[_wallet]) {
        address temp = highestPoints[0];
        highestPoints[0] = highestPoints[1];
        highestPoints[1] = temp;
    }
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
