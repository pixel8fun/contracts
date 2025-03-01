// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { MessageHashUtils } from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import { ERC721, IERC721TokenReceiver } from "src/ERC721.sol";
import { Auth } from "src/Auth.sol";
import { Pixel8 } from "src/Pixel8.sol";  
import { GameStats } from "src/GameStats.sol";

import {Test, console2 as c} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

abstract contract TestBase01 is Test {
  uint public owner1_key = 0x123;
  address payable owner1 = payable(vm.addr(owner1_key));

  uint public authoriser1_key = 0x1234;
  address payable authoriser1 = payable(vm.addr(authoriser1_key));

  uint public creator1_key = 0x1235;
  address payable creator1 = payable(vm.addr(creator1_key));

  address payable wallet1 = payable(address(0x1234567890));
  address payable wallet2 = payable(address(0x1234567890123));
  address payable wallet3 = payable(address(0x1234567890124));
  address payable wallet4 = payable(address(0x1234567890125));
  address payable wallet5 = payable(address(0x1234567890126));

  Pixel8 public pixel8;
  address public pixel8_addr;

  GameStats public gameStats;
  address public gameStats_addr;

  Pixel8.Config public defaultPixel8Config;

  constructor() payable {
    c.log("Test contract address", address(this));
    c.log("msg.sender", msg.sender);
  }

  function setUp() public virtual {   
    gameStats = new GameStats(owner1, address(0));
    gameStats_addr = address(gameStats);

    if (defaultPixel8Config.owner == address(0)) {
      defaultPixel8Config = _getDefaultPixel8Config();
    }

    if (defaultPixel8Config.linkedContracts.gameStats == address(0)) {
      defaultPixel8Config.linkedContracts.gameStats = gameStats_addr;
    }

    pixel8 = new Pixel8(defaultPixel8Config);
    pixel8_addr = address(pixel8);
  }

  // Helper methods

  function _getDefaultPixel8Config() internal view returns (Pixel8.Config memory) {
    return Pixel8.Config({
      name: "Pixel8",
      symbol: "PIXEL8",
      owner: owner1,
      authoriser: authoriser1,
      linkedContracts: Pixel8.LinkedContractsConfig({
        gameStats: address(0),
        pool: address(0)
      }),
      devRoyalty: Pixel8.Royalties({
        receiver: owner1,
        feeBips: 1000 // 10%
      }),
      creatorRoyalty: Pixel8.Royalties({
        receiver: creator1,
        feeBips: 500 // 5%
      }),
      defaultImage: "img",
      prizePoolFeeBips: 1000, /* 1000 bips = 10% */
      gameOverRevealThreshold: 10,
      forceSwapConfig: Pixel8.ForceSwap({
        cost: 0.01 ether,
        cooldownPeriod: 1 hours
      }),
      externalTradeThreshold: 10
    });
  }

  function _computeAuthoriserSig(bytes memory _data, uint _deadline) internal view returns (Auth.Signature memory) {
    return _computeSig(authoriser1_key, _data, _deadline);
  }

  function _computeOwnerSig(bytes memory _data, uint _deadline) internal view returns (Auth.Signature memory) {
    return _computeSig(owner1_key, _data, _deadline);
  }

  function _computeSig(uint _key, bytes memory _data, uint _deadline) internal pure returns (Auth.Signature memory) {
    bytes32 sigHash = MessageHashUtils.toEthSignedMessageHash(abi.encodePacked(_data, _deadline));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, sigHash);
    return Auth.Signature({
      signature: abi.encodePacked(r, s, v),
      deadline: _deadline
    });
  }

  function _pixel8_reveal(address _wallet, uint _tokenId, string memory _uri) internal {
    Pixel8.MintRevealParams memory params = Pixel8.MintRevealParams({
      wallet: _wallet,
      tokenId: _tokenId,
      uri: _uri,
      points: 50,
      authSig: _computeAuthoriserSig(
        abi.encodePacked(_wallet, _tokenId, _uri, uint(50)), 
        block.timestamp + 10 seconds
      )
    });

    pixel8.reveal(params);
  }

  function _pixel8_mint_and_reveal(address _wallet, uint _startId, uint _numTiles) internal {
    vm.prank(pixel8.pool());
    pixel8.batchMint(_wallet, _startId, _numTiles);

    for (uint i = _startId; i < _startId + _numTiles; i++) {
      _pixel8_reveal(_wallet, i, "uri");
    }
  }

  function _toBytes32(address _addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(_addr)));
  }

  // to exclude this file from coverage report
  function testTestBase01_ExcludeFromCoverage() public {}  
}




contract MockERC721 is ERC721 {
  uint public lastMintedId;
  bool public isAuthorizedOverride;

  constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

  function mint(address to, uint256 id, bytes memory data) public {
    _safeMint(to, id, data);
  }

  function burn(uint256 id) public {
    _burn(id);
  }

  function batchMint(address to, uint256 startId, uint256 count, bytes memory _data) public {
    _safeBatchMint(to, startId, count, _data);
    lastMintedId += count;
  }

  function batchTransfer(address from, address to, uint256[] calldata ids, bytes memory data) public {
    _safeBatchTransfer(msg.sender, from, to, ids, data);
  }

  function batchTransfer(address from, address to, uint256 count, bytes memory data) public returns (uint256) {
    return _safeBatchTransfer(msg.sender, from, to, count, data);
  }

  function tokenURI(uint256 /*id*/) public pure override returns (string memory) {
    return "uri";
  }

  function setIsAuthorizedOverride(bool _isAuthorizedOverride) public {
    isAuthorizedOverride = _isAuthorizedOverride;
  }

  function _isAuthorized(address caller, address from, uint256 id) internal view override returns (bool) {
    if (isAuthorizedOverride) {
      return true;
    }
    return super._isAuthorized(caller, from, id);
  }
}

contract GoodERC721Receiver is IERC721TokenReceiver {
  struct Received {
    address operator;
    address from;
    uint256 tokenId;
    bytes data;
  }

  Received[] internal received;

  function getReceived(uint i) public view returns (Received memory) {
    return received[i];
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    received.push(Received(operator, from, tokenId, data));
    return IERC721TokenReceiver.onERC721Received.selector;
  }
}

contract BadERC721Receiver is IERC721TokenReceiver {
  function onERC721Received(
    address /*operator*/,
    address /*from*/,
    uint256 /*tokenId*/,
    bytes calldata /*data*/
  ) public override pure returns (bytes4) {
    return 0x0;
  }
}

