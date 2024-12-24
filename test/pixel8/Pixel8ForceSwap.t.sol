// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { LibErrors } from "../../src/LibErrors.sol";

contract Pixel8ForceSwapTest is Pixel8TestBase {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address eve = makeAddr("eve");
    uint256 constant ALICE_TOKEN = 1;
    uint256 constant BOB_TOKEN = 2;
    uint256 constant EVE_TOKEN = 3;
    uint256 constant POOL_TOKEN = 4;

    function setUp() public override {
        super.setUp();

        // Set pool1 as the pool
        vm.prank(owner1);
        pixel8.setPool(pool1);
        
        // Mint tokens to test accounts
        vm.startPrank(pool1);
        pixel8.batchMint(alice, ALICE_TOKEN, 1);
        pixel8.batchMint(bob, BOB_TOKEN, 1);
        pixel8.batchMint(eve, EVE_TOKEN, 1);
        pixel8.batchMint(pool1, POOL_TOKEN, 1);
        vm.stopPrank();

        // Wait for token cooldown
        vm.warp(block.timestamp + 1 hours);
    }

    function test_ForceSwap_Basic() public {
        vm.prank(alice);
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);

        assertEq(pixel8.ownerOf(ALICE_TOKEN), bob);
        assertEq(pixel8.ownerOf(BOB_TOKEN), alice);
        assertEq(pixel8.numForceSwaps(alice), 1);
        assertEq(pixel8.highestNumForceSwaps(), alice);
    }

    function test_ForceSwap_RevertWhenSwappingUnownedToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, alice));
        pixel8.forceSwap(alice, BOB_TOKEN, ALICE_TOKEN);
    }

    function test_ForceSwap_RevertWhenUnauthorizedCaller() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, bob));
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);
    }

    function test_ForceSwap_RevertWhenSwappingSameToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidTokenId.selector, ALICE_TOKEN));
        pixel8.forceSwap(alice, ALICE_TOKEN, ALICE_TOKEN);
    }

    function test_ForceSwap_RevertWhenSwappingWithPoolToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOwnedByPool.selector, POOL_TOKEN));
        pixel8.forceSwap(alice, ALICE_TOKEN, POOL_TOKEN);
    }

    function test_ForceSwap_RevertWhenTokenOnCooldown() public {
        // Reset to time of minting
        vm.warp(block.timestamp - 1 hours);
        
        // Fast forward 30 mins after pool buy
        vm.warp(block.timestamp + 30 minutes);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOnCooldown.selector, BOB_TOKEN));
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);
    }

    function test_ForceSwap_RevertWhenTokenCooldownResetByPool() public {
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

    function test_ForceSwap_HighestForceSwapsUpdates() public {
        // Alice does first swap
        vm.prank(alice);
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);
        assertEq(pixel8.highestNumForceSwaps(), alice);

        // Fast forward 1 hour to bypass cooldown
        vm.warp(block.timestamp + 1 hours);

        // Bob does two swaps
        vm.prank(bob);
        pixel8.forceSwap(bob, ALICE_TOKEN, BOB_TOKEN);

        // Fast forward 1 hour to bypass cooldown
        vm.warp(block.timestamp + 1 hours);

        vm.prank(bob);
        pixel8.forceSwap(bob, BOB_TOKEN, ALICE_TOKEN);

        assertEq(pixel8.numForceSwaps(bob), 2);
        assertEq(pixel8.highestNumForceSwaps(), bob);
    }

    function test_ForceSwap_CooldownResetAfterSwap() public {
        // Initial force swap
        vm.prank(alice);
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);

        // Check cooldown times were reset
        assertEq(pixel8.lastCooldownStartTime(ALICE_TOKEN), block.timestamp);
        assertEq(pixel8.lastCooldownStartTime(BOB_TOKEN), block.timestamp);

        // Fast forward 30 minutes
        vm.warp(block.timestamp + 30 minutes);

        // Bob tries to force swap but fails due to cooldown
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOnCooldown.selector, BOB_TOKEN));
        pixel8.forceSwap(bob, ALICE_TOKEN, BOB_TOKEN);

        // Fast forward another 30 minutes (total 1 hour)
        vm.warp(block.timestamp + 30 minutes);

        // Now Bob can force swap
        vm.prank(bob);
        pixel8.forceSwap(bob, ALICE_TOKEN, BOB_TOKEN);

        // Check cooldown times were reset again
        assertEq(pixel8.lastCooldownStartTime(ALICE_TOKEN), block.timestamp);
        assertEq(pixel8.lastCooldownStartTime(BOB_TOKEN), block.timestamp);
    }

    function test_ForceSwap_CanSwapOwnTokenDuringCooldown() public {
        // Initial force swap to put BOB_TOKEN in cooldown
        vm.prank(alice);
        pixel8.forceSwap(alice, ALICE_TOKEN, BOB_TOKEN);

        // Check cooldown times were set
        assertEq(pixel8.lastCooldownStartTime(ALICE_TOKEN), block.timestamp);
        assertEq(pixel8.lastCooldownStartTime(BOB_TOKEN), block.timestamp);

        // Fast forward 30 minutes (ALICE_TOKEN still in cooldown)
        vm.warp(block.timestamp + 30 minutes);

        // Bob should be able to force swap ALICE_TOKEN with Eve's token
        // even though ALICE_TOKEN is in cooldown
        vm.prank(bob);
        pixel8.forceSwap(bob, ALICE_TOKEN, EVE_TOKEN);

        // Verify ownership
        assertEq(pixel8.ownerOf(BOB_TOKEN), alice);
        assertEq(pixel8.ownerOf(ALICE_TOKEN), eve);
        assertEq(pixel8.ownerOf(EVE_TOKEN), bob);
    }
} 