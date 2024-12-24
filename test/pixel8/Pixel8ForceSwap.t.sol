// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { LibErrors } from "../../src/LibErrors.sol";

contract Pixel8ForceSwapTest is Pixel8TestBase {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    uint256 constant ALICE_TOKEN = 1;
    uint256 constant BOB_TOKEN = 2;
    uint256 constant POOL_TOKEN = 3;

    function setUp() public override {
        super.setUp();

        // Set pool1 as the pool
        vm.prank(owner1);
        pixel8.setPool(pool1);
        
        // Mint tokens to test accounts
        vm.startPrank(pool1);
        pixel8.batchMint(alice, ALICE_TOKEN, 1);
        pixel8.batchMint(bob, BOB_TOKEN, 1);
        pixel8.batchMint(pool1, POOL_TOKEN, 1);
        vm.stopPrank();

        // Wait for token cooldown
        vm.warp(block.timestamp + 1 hours);
    }

    function test_ForceSwap() public {
        vm.prank(alice);
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);

        assertEq(pixel8.ownerOf(ALICE_TOKEN), bob);
        assertEq(pixel8.ownerOf(BOB_TOKEN), alice);
        assertEq(pixel8.numForceSwaps(alice), 1);
        assertEq(pixel8.highestNumForceSwaps(), alice);
    }

    function test_RevertWhen_SwappingUnownedToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, alice));
        pixel8.forceSwap(alice, BOB_TOKEN, ALICE_TOKEN);
    }

    function test_RevertWhen_UnauthorizedCaller() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, bob));
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);
    }

    function test_RevertWhen_SwappingSameToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidTokenId.selector, ALICE_TOKEN));
        pixel8.forceSwap(alice, ALICE_TOKEN, ALICE_TOKEN);
    }

    function test_RevertWhen_SwappingWithPoolToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOwnedByPool.selector, POOL_TOKEN));
        pixel8.forceSwap(alice, ALICE_TOKEN, POOL_TOKEN);
    }

    function test_RevertWhen_TokenOnCooldown() public {
        // Reset to time of minting
        vm.warp(block.timestamp - 1 hours);
        
        // Fast forward 30 mins after pool buy
        vm.warp(block.timestamp + 30 minutes);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOnCooldown.selector, BOB_TOKEN));
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);
    }

    function test_RevertWhen_TokenCooldownResetByPool() public {
        // Bob trades token to pool
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = BOB_TOKEN;
        vm.prank(pool1);
        pixel8.batchTransferIds(bob, pool1, tokenIds);

        // Pool trades token back to Bob
        vm.prank(pool1);
        pixel8.batchTransferIds(pool1, bob, tokenIds);

        // Alice tries to force swap but fails due to cooldown
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOnCooldown.selector, BOB_TOKEN));
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);
    }

    function test_HighestForceSwapsUpdates() public {
        // Alice does first swap
        vm.prank(alice);
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);
        assertEq(pixel8.highestNumForceSwaps(), alice);

        // Bob does two swaps
        vm.prank(bob);
        pixel8.forceSwap(bob, ALICE_TOKEN, BOB_TOKEN);
        
        vm.prank(bob);
        pixel8.forceSwap(bob, BOB_TOKEN, ALICE_TOKEN);

        assertEq(pixel8.numForceSwaps(bob), 2);
        assertEq(pixel8.highestNumForceSwaps(), bob);
    }
} 