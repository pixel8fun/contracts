// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { IERC165 } from "openzeppelin/interfaces/IERC165.sol";
import { IERC721 } from "openzeppelin/interfaces/IERC721.sol";
import { IERC721Metadata } from "openzeppelin/interfaces/IERC721Metadata.sol";
import { IERC721Enumerable } from "openzeppelin/interfaces/IERC721Enumerable.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";
import { TestBase01, MockERC721, GoodERC721Receiver, BadERC721Receiver} from "../utils/TestBase01.sol";
import { Bytes32AddressLib } from "solmate/utils/Bytes32AddressLib.sol";


contract Erc721Base is TestBase01 {
  MockERC721 b;

  function setUp() public override {
    b = new MockERC721("Test", "TEST");
  }

  // Basic

  function test_BasicDetails() public {
    assertEq(b.name(), "Test");
    assertEq(b.symbol(), "TEST");
    assertEq(b.totalSupply(), 0);
  }

  function test_SupportsInterface() public {
    assertTrue(b.supportsInterface(type(IERC165).interfaceId));
    assertTrue(b.supportsInterface(type(IERC721).interfaceId));
    assertTrue(b.supportsInterface(type(IERC721Metadata).interfaceId));
    assertTrue(b.supportsInterface(type(IERC721Enumerable).interfaceId));
  }

  function test_TokenURI() public {
    assertEq(b.tokenURI(1), "uri");
    assertEq(b.tokenURI(2), "uri");
  }

  function test_BalanceOf_ZeroAddress_Fails() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    b.balanceOf(address(0));
  }

  // Mint

  function test_SingleMint_UpdatesEnumeration() public {
    b.mint(wallet1, 1, "");
    b.mint(wallet1, 2, "");

    assertEq(b.totalSupply(), 2);
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 1), 2);
    assertEq(b.balanceOf(wallet1), 2);
    assertEq(b.ownerOf(1), wallet1);
    assertEq(b.ownerOf(2), wallet1);

    b.mint(wallet2, 3, "");
    assertEq(b.totalSupply(), 3);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 3);
    assertEq(b.balanceOf(wallet2), 1);
    assertEq(b.ownerOf(3), wallet2);
  }

  function test_SingleMint_FiresTransferEvent() public {
    vm.recordLogs();

    b.mint(wallet1, 1, "");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[0].topics[1], bytes32(0), "Invalid from");
    assertEq(entries[0].topics[2], _toBytes32(wallet1), "Invalid to");
    assertEq(entries[0].topics[3], bytes32(uint(1)), "Invalid tokenId");
  }

  function test_SingleMint_InvokesReceiver_Good() public {
    address good = address(new GoodERC721Receiver());

    vm.prank(wallet1);
    b.mint(good, 1, "test");

    assertEq(b.ownerOf(1), good);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, wallet1);
    assertEq(r.from, address(0));
    assertEq(r.tokenId, 1);
    assertEq(r.data, "test");
  }

  function test_SingleMint_InvokesReceiver_Bad() public {
    address bad = address(new BadERC721Receiver());

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721UnsafeTokenReceiver.selector, bad, uint(1)));
    b.mint(bad, 1, "test");
  }

  function test_SingleMintAlreadyMintedToken_Fails() public {
    b.mint(wallet1, 1, "");
    
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenAlreadyMinted.selector, uint(1)));
    b.mint(wallet1, 1, "");
  }

  function test_SingleMintToZeroAddress_Fails() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    b.mint(address(0), 1, "");
  }

  // Batch mint

  function test_BatchMint_UpdatesEnumeration() public {
    b.batchMint(wallet1, 1, 2, "");
    b.batchMint(wallet2, 3, 1, "");

    assertEq(b.totalSupply(), 3);
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 1), 2);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 3);
    assertEq(b.balanceOf(wallet1), 2);
    assertEq(b.balanceOf(wallet2), 1);
    assertEq(b.ownerOf(1), wallet1);
    assertEq(b.ownerOf(2), wallet1);
    assertEq(b.ownerOf(3), wallet2);
  }

  function test_BatchMint_FiresTransferEvent() public {
    vm.recordLogs();

    b.batchMint(wallet1, 1, 2, "");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 2, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[1].topics.length, 4, "Invalid event count");
    assertEq(
        entries[1].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
  }

  function test_BatchMint_InvokesReceiver_Good() public {
    address good = address(new GoodERC721Receiver());

    vm.prank(wallet1);
    b.batchMint(good, 1, 2, "test");

    assertEq(b.ownerOf(1), good);
    assertEq(b.ownerOf(2), good);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, wallet1);
    assertEq(r.from, address(0));
    assertEq(r.tokenId, 1);
    assertEq(r.data, "test");

    r = GoodERC721Receiver(good).getReceived(1);
    assertEq(r.operator, wallet1);
    assertEq(r.from, address(0));
    assertEq(r.tokenId, 2);
    assertEq(r.data, "test");
  }

  function test_BatchMint_InvokesReceiver_Bad() public {
    address bad = address(new BadERC721Receiver());

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721UnsafeTokenReceiver.selector, bad, uint(1)));
    b.mint(bad, 1, "test");
  }

  function test_BatchMint_ToZeroAddress_Fails() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    b.batchMint(address(0), 1, 2, "");
  }

  function test_BatchMint_EmptyBatch_Fails() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidBatchSize.selector, uint(0)));
    b.batchMint(wallet1, 1, 0, "");
  }

  // Single token Approval

  function test_SingleTokenApproval() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, uint(1)));
    b.transferFrom(wallet1, wallet2, 1);

    vm.prank(wallet1);
    b.approve(wallet2, 1);
    assertEq(b.getApproved(1), wallet2);

    vm.prank(wallet2);
    b.transferFrom(wallet1, wallet2, 1);

    assertEq(b.ownerOf(1), wallet2);
  }

  function test_SingleTokenApproval_TransferCancelsApprovals() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet1);
    b.approve(wallet2, 1);

    vm.prank(wallet2);
    b.transferFrom(wallet1, wallet2, 1);

    assertEq(b.getApproved(1), address(0));
  }

  function test_SingleTokenApproval_EmitsEvent() public {
    b.mint(wallet1, 1, "");

    vm.recordLogs();

    vm.prank(wallet1);
    b.approve(wallet2, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Approval(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[0].topics[1], _toBytes32(wallet1), "Invalid owner");
    assertEq(entries[0].topics[2], _toBytes32(wallet2), "Invalid spender");
    assertEq(entries[0].topics[3], bytes32(uint(1)), "Invalid id");
  }

  function test_SingleTokenApproval_AnonCannotApprove() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, uint(1)));
    b.approve(wallet2, 1);
  }

  // All tokens Approval

  function test_AllTokenApproval() public {
    b.mint(wallet1, 1, "");
    b.mint(wallet1, 2, "");

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, uint(1)));
    b.transferFrom(wallet1, wallet2, 1);

    vm.prank(wallet1);
    b.setApprovalForAll(wallet2, true);
    assertTrue(b.isApprovedForAll(wallet1, wallet2));

    vm.prank(wallet2);
    b.transferFrom(wallet1, wallet2, 1);

    assertEq(b.ownerOf(1), wallet2);

    vm.prank(wallet1);
    b.setApprovalForAll(wallet2, false);
    assertFalse(b.isApprovedForAll(wallet1, wallet2));

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, uint(2)));
    b.transferFrom(wallet1, wallet2, 2);
  }

  function test_AllTokenApproval_EmitsEvent() public {
    vm.recordLogs();

    vm.prank(wallet1);
    b.setApprovalForAll(wallet2, true);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 3, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("ApprovalForAll(address,address,bool)"),
        "Invalid event signature"
    );
    assertEq(entries[0].topics[1], _toBytes32(wallet1), "Invalid owner");
    assertEq(entries[0].topics[2], _toBytes32(wallet2), "Invalid operator");
    (bool val) = abi.decode(entries[0].data, (bool));
    assertTrue(val, "Invalid approved");
  }

  // Single transfers

  function test_TransferFrom_UpdatesEnumeration() public {
    b.mint(wallet1, 1, "");
    b.mint(wallet1, 2, "");
    b.mint(wallet2, 3, "");

    vm.startPrank(wallet1);
    b.transferFrom(wallet1, wallet2, 1);
    b.transferFrom(wallet1, wallet2, 2);
    vm.stopPrank();

    assertEq(b.totalSupply(), 3);
    
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);

    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 0);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 1), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 2), 2);

    assertEq(b.balanceOf(wallet1), 0);
    assertEq(b.balanceOf(wallet2), 3);
  }

  function test_TransferFrom_IfSingleTokenApproved() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet1);
    b.approve(wallet2, 1);

    vm.prank(wallet2);
    b.transferFrom(wallet1, wallet2, 1);

    assertEq(b.ownerOf(1), wallet2);
  }

  function test_TransferFrom_IfAllTokensApproved() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet1);
    b.setApprovalForAll(wallet2, true);

    vm.prank(wallet2);
    b.transferFrom(wallet1, wallet2, 1);

    assertEq(b.ownerOf(1), wallet2);
  }

  function test_TransferFrom_CancelsSingleTokenApprovals() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet1);
    b.approve(wallet2, 1);

    vm.prank(wallet1);
    b.transferFrom(wallet1, wallet2, 1);

    assertEq(b.getApproved(1), address(0));
  }

  function test_TransferFrom_FiresTransferEvent() public {
    b.mint(wallet1, 1, "");

    vm.recordLogs();

    vm.prank(wallet1);
    b.transferFrom(wallet1, wallet2, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[0].topics[1], _toBytes32(wallet1), "Invalid from");
    assertEq(entries[0].topics[2], _toBytes32(wallet2), "Invalid to");
    assertEq(entries[0].topics[3], bytes32(uint(1)), "Invalid tokenId");
  }

  function test_TransferFrom_InvalidFrom_Fails() public {
    b.mint(wallet2, 1, "");

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, wallet1, uint(1)));
    b.transferFrom(wallet1, wallet2, 1);
  }

  function test_TransferFrom_ToZeroAddress_Fails() public {
    b.mint(wallet2, 1, "");

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    b.transferFrom(wallet2, address(0), 1);
  }  

  // Safe single transfers

  function test_SafeTransferFrom_UpdatesEnumeration() public {
    b.mint(wallet1, 1, "");
    b.mint(wallet1, 2, "");
    b.mint(wallet2, 3, "");

    vm.startPrank(wallet1);
    b.safeTransferFrom(wallet1, wallet2, 1, "");
    b.safeTransferFrom(wallet1, wallet2, 2, "");
    vm.stopPrank();

    assertEq(b.totalSupply(), 3);
    
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);

    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 0);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 1), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 2), 2);

    assertEq(b.balanceOf(wallet1), 0);
    assertEq(b.balanceOf(wallet2), 3);
  }

  function test_SafeTransferFrom_IfSingleTokenApproved() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet1);
    b.approve(wallet2, 1);

    vm.prank(wallet2);
    b.safeTransferFrom(wallet1, wallet2, 1);

    assertEq(b.ownerOf(1), wallet2);
  }

  function test_SafeTransferFrom_IfAllTokensApproved() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet1);
    b.setApprovalForAll(wallet2, true);

    vm.prank(wallet2);
    b.safeTransferFrom(wallet1, wallet2, 1);

    assertEq(b.ownerOf(1), wallet2);
  }

  function test_SafeTransferFrom_CancelsSingleTokenApprovals() public {
    b.mint(wallet1, 1, "");

    vm.prank(wallet1);
    b.approve(wallet2, 1);

    vm.prank(wallet1);
    b.safeTransferFrom(wallet1, wallet2, 1, "");

    assertEq(b.getApproved(1), address(0));
  }

  function test_SafeTransferFrom_FiresTransferEvent() public {
    b.mint(wallet1, 1, "");

    vm.recordLogs();

    vm.prank(wallet1);
    b.safeTransferFrom(wallet1, wallet2, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[0].topics[1], _toBytes32(wallet1), "Invalid from");
    assertEq(entries[0].topics[2], _toBytes32(wallet2), "Invalid to");
    assertEq(entries[0].topics[3], bytes32(uint(1)), "Invalid tokenId");
  }

  function test_SafeTransferFrom_InvokesReceiver_Good() public {
    address good = address(new GoodERC721Receiver());

    vm.startPrank(wallet1);
    b.mint(wallet1, 1, "");
    b.safeTransferFrom(wallet1, good, 1, "test");
    vm.stopPrank();

    assertEq(b.ownerOf(1), good);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, wallet1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 1);
    assertEq(r.data, "test");
  }

  function test_SafeTransferFrom_InvalidFrom_Fails() public {
    b.mint(wallet2, 1, "");

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, wallet1, uint(1)));
    b.safeTransferFrom(wallet1, wallet2, 1);
  }

  function test_SafeTransferFrom_ToZeroAddress_Fails() public {
    b.mint(wallet2, 1, "");

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    b.safeTransferFrom(wallet2, address(0), 1);
  }

  function test_SafeTransferFromWithoutData_InvokesReceiver_Good() public {
    address good = address(new GoodERC721Receiver());

    vm.startPrank(wallet1);
    b.mint(wallet1, 1, "");
    b.safeTransferFrom(wallet1, good, 1);
    vm.stopPrank();

    assertEq(b.ownerOf(1), good);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, wallet1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 1);
    assertEq(r.data, "");
  }

  function test_SafeTransferFrom_InvokesReceiver_Bad() public {
    address bad = address(new BadERC721Receiver());

    vm.startPrank(wallet1);
    b.mint(wallet1, 1, "");
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721UnsafeTokenReceiver.selector, bad, uint(1)));
    b.safeTransferFrom(wallet1, bad, 1, "test");
    vm.stopPrank();
  }

  // Safe Batch Transfer - specific ids
  
  function _mintTokensForBatchTransferIdsTest() internal returns (uint[] memory ids) {
    b.mint(wallet1, 1, "");
    b.mint(wallet1, 2, "");
    b.mint(wallet1, 3, "");
    b.mint(wallet1, 4, "");
    b.mint(wallet2, 5, "");

    ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;
  }

  function test_SafeBatchTransferIds_UpdatesEnumeration() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.startPrank(wallet1);
    b.batchTransfer(wallet1, wallet2, ids, "");
    vm.stopPrank();

    assertEq(b.totalSupply(), 5);
    
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenByIndex(3), 4);
    assertEq(b.tokenByIndex(4), 5);

    /*
    The reverse order is due to the fact that the last token is 
    moved to the position of the token being removed from the lispuzzArt.
    */
    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 4);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 1), 3);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 5);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 1), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 2), 2);

    assertEq(b.balanceOf(wallet1), 2);
    assertEq(b.balanceOf(wallet2), 3);
  }

  function test_SafeBatchTransferIds_CanTransferAll() public {
    _mintTokensForBatchTransferIdsTest();

    uint[] memory ids = new uint[](4);
    ids[0] = 1;
    ids[1] = 2;
    ids[2] = 3;
    ids[3] = 4;

    vm.startPrank(wallet1);
    b.batchTransfer(wallet1, wallet2, ids, "");
    vm.stopPrank();

    assertEq(b.totalSupply(), 5);
  
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenByIndex(3), 4);
    assertEq(b.tokenByIndex(4), 5);

    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 0);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 5);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 1), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 2), 2);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 3), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 4), 4);

    assertEq(b.balanceOf(wallet1), 0);
    assertEq(b.balanceOf(wallet2), 5);
  }

  function test_SafeBatchTransferIds_CanTransferNone() public {
    _mintTokensForBatchTransferIdsTest();

    uint[] memory ids = new uint[](0);

    vm.prank(wallet1);
    b.batchTransfer(wallet1, wallet2, ids, "");

    assertEq(b.totalSupply(), 5);

    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenByIndex(3), 4);
    assertEq(b.tokenByIndex(4), 5);

    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 1), 2);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 2), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 3), 4);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 5);

    assertEq(b.balanceOf(wallet1), 4);
    assertEq(b.balanceOf(wallet2), 1);
  }

  function test_SafeBatchTransferIds_IfTokensApprovedIndividually() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.startPrank(wallet1);
    b.approve(wallet2, 1);
    b.approve(wallet2, 2);
    vm.stopPrank();

    vm.prank(wallet2);
    b.batchTransfer(wallet1, wallet2, ids, "");

    assertEq(b.ownerOf(1), wallet2);
    assertEq(b.ownerOf(2), wallet2);
  }

  function test_SafeBatchTransferIds_IfNotAllTokensApprovedIndividually_Fails() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.startPrank(wallet1);
    b.approve(wallet2, 1);
    vm.stopPrank();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, uint(2)));
    b.batchTransfer(wallet1, wallet2, ids, "");
  }

  function test_SafeBatchTransferIds_IfAllTokensApproved() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.prank(wallet1);
    b.setApprovalForAll(wallet2, true);

    vm.prank(wallet2);
    b.batchTransfer(wallet1, wallet2, ids, "");

    assertEq(b.ownerOf(1), wallet2);
    assertEq(b.ownerOf(2), wallet2);
  }

  function test_SafeBatchTransferIds_CancelsSingleTokenApprovals() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.startPrank(wallet1);
    b.approve(wallet2, 1);
    b.approve(wallet2, 2);
    vm.stopPrank();

    vm.prank(wallet2);
    b.batchTransfer(wallet1, wallet2, ids, "");

    assertEq(b.getApproved(1), address(0));
    assertEq(b.getApproved(2), address(0));
  }

  function test_SafeBatchTransferIds_FiresTransferEvents() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.recordLogs();

    vm.prank(wallet1);
    b.batchTransfer(wallet1, wallet2, ids, "");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 2, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[1].topics.length, 4, "Invalid event count");
    assertEq(
        entries[1].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
  }

  function test_SafeBatchTransferIds_InvalidFrom_Fails() public {    
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, wallet2, uint(1)));
    b.batchTransfer(wallet2, wallet1, ids, "");
  }

  function test_SafeBatchTransferIds_ToZeroAddress_Fails() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    b.batchTransfer(wallet1, address(0), ids, "");
  }

  function test_SafeBatchTransferIds_InvokesReceiver_Good() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    address good = address(new GoodERC721Receiver());

    vm.prank(wallet1);
    b.batchTransfer(wallet1, good, ids, "test");

    assertEq(b.ownerOf(1), good);
    assertEq(b.ownerOf(2), good);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, wallet1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 1);
    assertEq(r.data, "test");

    r = GoodERC721Receiver(good).getReceived(1);
    assertEq(r.operator, wallet1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 2);
    assertEq(r.data, "test");
  }

  function test_SafeBatchTransferIds_InvokesReceiver_Bad() public {
    uint[] memory ids = _mintTokensForBatchTransferIdsTest();

    address bad = address(new BadERC721Receiver());

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721UnsafeTokenReceiver.selector, bad, uint(1)));
    b.batchTransfer(wallet1, bad, ids, "test");
  }

  // Safe Batch Transfer - range
  
  function _mintTokensForBatchTransferRangeTest() internal {
    b.mint(wallet1, 1, "");
    b.mint(wallet1, 2, "");
    b.mint(wallet1, 3, "");
    b.mint(wallet1, 4, "");
    b.mint(wallet2, 5, "");
  }

  function test_SafeBatchTransferRange_UpdatesEnumeration() public {
    _mintTokensForBatchTransferRangeTest();

    vm.prank(wallet1);
    b.batchTransfer(wallet1, wallet2, 2, "");

    assertEq(b.totalSupply(), 5);
    
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenByIndex(3), 4);
    assertEq(b.tokenByIndex(4), 5);

    /**
    Batch transfer range counts tokens from the end of the list backwards so that the 
    list order is preserved, i.e. it transfers the most recently received tokens firspuzzArt.
    */
    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 1), 2);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 5);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 1), 4);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 2), 3);

    assertEq(b.balanceOf(wallet1), 2);
    assertEq(b.balanceOf(wallet2), 3);
  }

  function test_SafeBatchTransferRange_CanTransferAll() public {
    _mintTokensForBatchTransferRangeTest();

    vm.prank(wallet1);
    b.batchTransfer(wallet1, wallet2, 4, "");

    assertEq(b.totalSupply(), 5);
  
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenByIndex(3), 4);
    assertEq(b.tokenByIndex(4), 5);

    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 0);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 5);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 1), 4);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 2), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 3), 2);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 4), 1);

    assertEq(b.balanceOf(wallet1), 0);
    assertEq(b.balanceOf(wallet2), 5);
  }

  function test_SafeBatchTransferRange_CanTransferNone() public {
    _mintTokensForBatchTransferRangeTest();

    vm.prank(wallet1);
    b.batchTransfer(wallet1, wallet2, 0, "");

    assertEq(b.totalSupply(), 5);

    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 2);
    assertEq(b.tokenByIndex(2), 3);
    assertEq(b.tokenByIndex(3), 4);
    assertEq(b.tokenByIndex(4), 5);

    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 1), 2);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 2), 3);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 3), 4);

    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 5);

    assertEq(b.balanceOf(wallet1), 4);
    assertEq(b.balanceOf(wallet2), 1);
  }

  function test_SafeBatchTransferRange_IfTokensApprovedIndividually() public {
    _mintTokensForBatchTransferRangeTest();

    vm.startPrank(wallet1);
    b.approve(wallet2, 3);
    b.approve(wallet2, 4);
    vm.stopPrank();

    vm.prank(wallet2);
    b.batchTransfer(wallet1, wallet2, 2, "");

    assertEq(b.ownerOf(3), wallet2);
    assertEq(b.ownerOf(4), wallet2);
  }

  function test_SafeBatchTransferRange_IfNotAllTokensApprovedIndividually_Fails() public {
    _mintTokensForBatchTransferIdsTest();

    vm.startPrank(wallet1);
    b.approve(wallet2, 3);
    vm.stopPrank();

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NotAuthorized.selector, wallet1, wallet2, uint(4)));
    b.batchTransfer(wallet1, wallet2, 2, "");
  }

  function test_SafeBatchTransferRange_IfAllTokensApproved() public {
    _mintTokensForBatchTransferRangeTest();

    vm.prank(wallet1);
    b.setApprovalForAll(wallet2, true);

    vm.prank(wallet2);
    b.batchTransfer(wallet1, wallet2, 2, "");

    assertEq(b.ownerOf(3), wallet2);
    assertEq(b.ownerOf(4), wallet2);
  }

  function test_SafeBatchTransferRange_CancelsSingleTokenApprovals() public {
    _mintTokensForBatchTransferRangeTest();

    vm.startPrank(wallet1);
    b.approve(wallet2, 3);
    b.approve(wallet2, 4);
    vm.stopPrank();

    vm.prank(wallet2);
    b.batchTransfer(wallet1, wallet2, 2, "");

    assertEq(b.getApproved(3), address(0));
    assertEq(b.getApproved(4), address(0));
  }

  function test_SafeBatchTransferRange_FiresTransferEvents() public {
    _mintTokensForBatchTransferRangeTest();

    vm.recordLogs();

    vm.prank(wallet1);
    b.batchTransfer(wallet1, wallet2, 2, "");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 2, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[1].topics.length, 4, "Invalid event count");
    assertEq(
        entries[1].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
  }

  function test_SafeBatchTransferRange_ToZeroAddress_Fails() public {
    _mintTokensForBatchTransferRangeTest();

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721ZeroAddress.selector));
    b.batchTransfer(wallet1, address(0), 2, "");
  }

  function test_SafeBatchTransferRange_TooMuch_Fails() public {
    _mintTokensForBatchTransferRangeTest();

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientBalance.selector, wallet1, uint(5), uint(4)));
    b.batchTransfer(wallet1, wallet2, 5, "");
  }

  function test_SafeBatchTransferRange_InvokesReceiver_Good() public {
    _mintTokensForBatchTransferRangeTest();

    address good = address(new GoodERC721Receiver());

    vm.prank(wallet1);
    b.batchTransfer(wallet1, good, 2, "test");

    assertEq(b.ownerOf(3), good);
    assertEq(b.ownerOf(4), good);

    GoodERC721Receiver.Received memory r = GoodERC721Receiver(good).getReceived(0);
    assertEq(r.operator, wallet1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 4);
    assertEq(r.data, "test");

    r = GoodERC721Receiver(good).getReceived(1);
    assertEq(r.operator, wallet1);
    assertEq(r.from, wallet1);
    assertEq(r.tokenId, 3);
    assertEq(r.data, "test");
  }

  function test_SafeBatchTransferRange_InvokesReceiver_Bad() public {
    _mintTokensForBatchTransferRangeTest();

    address bad = address(new BadERC721Receiver());

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721UnsafeTokenReceiver.selector, bad, uint(4)));
    b.batchTransfer(wallet1, bad, 2, "test");
  }

  // Burn

  function test_Burn_UpdatesEnumeration() public {
    b.mint(wallet1, 1, "");
    b.mint(wallet1, 2, "");
    b.mint(wallet2, 3, "");
    b.mint(wallet2, 4, "");
    b.mint(wallet2, 5, "");

    b.burn(5); // last item in tokenByIndex and tokenOfOwnerByIndex(wallet2)
    b.burn(2); // last item in tokenOfOwnerByIndex(wallet1)
    b.burn(3); // first item in tokenOfOwnerByIndex(wallet2)

    assertEq(b.totalSupply(), 2);
    assertEq(b.tokenByIndex(0), 1);
    assertEq(b.tokenByIndex(1), 4);
    assertEq(b.tokenByIndex(2), 0);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 0), 1);
    assertEq(b.tokenOfOwnerByIndex(wallet1, 1), 0);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 0), 4);
    assertEq(b.tokenOfOwnerByIndex(wallet2, 1), 0);
    assertEq(b.balanceOf(wallet1), 1);
    assertEq(b.balanceOf(wallet2), 1);
    assertEq(b.ownerOf(1), wallet1);
    assertEq(b.ownerOf(4), wallet2);

    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenNotMinted.selector, uint(2)));
    assertEq(b.ownerOf(2), address(0));
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenNotMinted.selector, uint(3)));
    assertEq(b.ownerOf(3), address(0));
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenNotMinted.selector, uint(5)));
    assertEq(b.ownerOf(5), address(0));
  }

  function test_Burn_CancelsApprovals() public {
    b.mint(wallet1, 1, "");
    
    vm.prank(wallet1);
    b.approve(wallet2, 1);
    b.burn(1);

    assertEq(b.getApproved(1), address(0));
  }

  function test_Burn_FiresTransferEvent() public {
    b.mint(wallet1, 1, "");
    vm.recordLogs();

    b.burn(1);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 4, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("Transfer(address,address,uint256)"),
        "Invalid event signature"
    );
    assertEq(entries[0].topics[1], _toBytes32(wallet1), "Invalid from");
    assertEq(entries[0].topics[2], bytes32(0), "Invalid to");
    assertEq(entries[0].topics[3], bytes32(uint(1)), "Invalid tokenId");
  }

  function test_BurnUnmintedToken_Fails() public {
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721TokenNotMinted.selector, uint(1)));
    b.burn(1);
  }
}

