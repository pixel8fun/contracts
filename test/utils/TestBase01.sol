// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { MessageHashUtils } from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import { ERC721, IERC721TokenReceiver } from "src/ERC721.sol";
import { Auth } from "src/Auth.sol";
import { Pixel8 } from "src/Pixel8.sol";  
import { LotteryNFT } from "src/LotteryNFT.sol";

import {Test, console2 as c} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

abstract contract TestBase01 is Test {
  uint public owner1_key = 0x123;
  address payable owner1 = payable(vm.addr(owner1_key));

  uint public minter1_key = 0x1234;
  address payable minter1 = payable(vm.addr(minter1_key));

  address payable wallet1 = payable(address(0x1234567890));
  address payable wallet2 = payable(address(0x1234567890123));

  Pixel8 public pixel8;
  address pixel8_addr;

  LotteryNFT public lotteryNft;
  address lotteryNft_addr;

  constructor() payable {
    c.log("Test contract address", address(this));
    c.log("msg.sender", msg.sender);
  }

  function setUp() public virtual {    
    pixel8 = new Pixel8(_getDefaultPixel8NftConfig());
    pixel8_addr = address(pixel8);

    lotteryNft = new LotteryNFT(_getDefaultLotteryNftConfig(pixel8));
    lotteryNft_addr = address(lotteryNft);
  }

  // Helper methods

  function _getDefaultPixel8NftConfig() internal view returns (Pixel8.Config memory) {
    return Pixel8.Config({
      owner: owner1,
      minter: minter1,
      devRoyaltyFeeBips: 1000, /* 1000 bips = 10% */
      defaultImage: "img",
      devRoyaltyReceiver: owner1,
      lotteryPotFeeBips: 1000, /* 1000 bips = 10% */
      lotteryDeadline: block.timestamp + 10,
      lotteryRevealThreshold: 10
    });
  }  

  function _getDefaultLotteryNftConfig(Pixel8 t) internal view returns (LotteryNFT.Config memory) {
    return LotteryNFT.Config({
      owner: owner1,
      minter: address(t),
      defaultImage: "img",
      royaltyReceiver: owner1,
      royaltyFeeBips: 1000
    });
  }

  function _computeMinterSig(bytes memory _data, uint _deadline) internal view returns (Auth.Signature memory) {
    return _computeSig(minter1_key, _data, _deadline);
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

  function _pixel8_mint(address _wallet, uint _tokenId, string memory _uri, uint _lotteryTickets) internal {
    Pixel8.MintRevealParams memory params = Pixel8.MintRevealParams({
      wallet: _wallet,
      tokenId: _tokenId,
      uri: _uri,
      lotteryTickets: _lotteryTickets,
      authSig: _computeMinterSig(
        abi.encodePacked(_wallet, _tokenId, _uri, _lotteryTickets), 
        block.timestamp + 10 seconds
      )
    });

    pixel8.mint(params);
  }

  function _pixel8_reveal(address _wallet, uint _tokenId, string memory _uri, uint _lotteryTickets) internal {
    Pixel8.MintRevealParams memory params = Pixel8.MintRevealParams({
      wallet: _wallet,
      tokenId: _tokenId,
      uri: _uri,
      lotteryTickets: _lotteryTickets,
      authSig: _computeMinterSig(
        abi.encodePacked(_wallet, _tokenId, _uri, _lotteryTickets), 
        block.timestamp + 10 seconds
      )
    });

    pixel8.reveal(params);
  }

  function _toBytes32(address _addr) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(_addr)));
  }

  // to exclude this file from coverage report
  function testTestBase01_ExcludeFromCoverage() public {}  
}




contract MockERC721 is ERC721 {
  uint lastMintedId;

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

  function batchTransfer(address from, address to, uint count, bytes memory data) public {
    _safeBatchTransfer(msg.sender, from, to, count, data);
  }

  function tokenURI(uint256 /*id*/) public pure override returns (string memory) {
    return "uri";
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

