// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { console2 as c } from "forge-std/console2.sol";
import { Vm } from "forge-std/Vm.sol";
import { Pixel8 } from "../../src/Pixel8.sol";
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
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod);

        // add enough funds to each wallet
        vm.deal(alice, 0.02 ether);
        vm.deal(bob, 0.02 ether);
        vm.deal(eve, 0.02 ether);
    }

    function test_ForceSwap_Basic() public {
        vm.prank(alice);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        assertEq(pixel8.ownerOf(ALICE_TOKEN), bob);
        assertEq(pixel8.ownerOf(BOB_TOKEN), alice);
        assertEq(gameStats.numForceSwaps(pixel8_addr, alice), 1);
        assertEq(gameStats.highestNumForceSwaps(pixel8_addr), alice);
        assertEq(gameStats.getPrizesWinners(pixel8_addr).biggestThief, alice);
        assertEq(gameStats.getPrizesWinners(pixel8_addr).biggestThiefPoints, 1);
    }

    function test_ForceSwap_RevertWhenInsufficientPayment() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InsufficientSenderFunds.selector, alice, 0.01 ether, 0.005 ether));
        pixel8.forceSwap{value: 0.005 ether}(ALICE_TOKEN, BOB_TOKEN);
    }

    function test_ForceSwap_RevertWhenSwappingUnownedToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, alice));
        pixel8.forceSwap{value: 0.01 ether}(BOB_TOKEN, ALICE_TOKEN);
    }

    function test_ForceSwap_RevertWhenUnauthorizedCaller() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, bob));
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);
    }

    function test_ForceSwap_RevertWhenSwappingSameToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidTokenId.selector, ALICE_TOKEN));
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, ALICE_TOKEN);
    }

    function test_ForceSwap_RevertWhenSwappingWithPoolToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOwnedByPool.selector, POOL_TOKEN));
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, POOL_TOKEN);
    }

    function test_ForceSwap_RevertWhenTokenOnCooldown() public {
        // Reset to time of minting
        vm.warp(block.timestamp - pixel8.getForceSwapConfig().cooldownPeriod);
        
        // Fast forward 30 mins after pool buy
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod / 2);
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOnCooldown.selector, BOB_TOKEN));
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);
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
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);
    }

    function test_ForceSwap_HighestForceSwapsUpdates() public {
        // Alice does first swap
        vm.prank(alice);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);
        assertEq(gameStats.highestNumForceSwaps(pixel8_addr), alice);
        assertEq(gameStats.getPrizesWinners(pixel8_addr).biggestThief, alice);

        // Fast forward 1 hour to bypass cooldown
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod);

        // Bob does two swaps
        vm.prank(bob);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        // Fast forward 1 hour to bypass cooldown
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod);

        vm.prank(bob);
        pixel8.forceSwap{value: 0.01 ether}(BOB_TOKEN, ALICE_TOKEN);

        assertEq(gameStats.numForceSwaps(pixel8_addr, bob), 2);
        assertEq(gameStats.highestNumForceSwaps(pixel8_addr), bob);
        assertEq(gameStats.getPrizesWinners(pixel8_addr).biggestThief, bob);
    }

    function test_ForceSwap_CooldownResetAfterSwap() public {
        // Initial force swap
        vm.prank(alice);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        // Check cooldown times were reset
        assertEq(pixel8.lastCooldownStartTime(ALICE_TOKEN), block.timestamp);
        assertEq(pixel8.lastCooldownStartTime(BOB_TOKEN), block.timestamp);

        // Verify getTileState() returns correct cooldown start time
        Pixel8.TileState memory tileStateAlice = pixel8.getTileState(ALICE_TOKEN);
        assertEq(tileStateAlice.lastCooldownStartTime, block.timestamp, "Incorrect last cooldown start time for ALICE_TOKEN");
        assertEq(tileStateAlice.owner, bob, "ALICE_TOKEN should be owned by bob after swap");

        Pixel8.TileState memory tileStateBob = pixel8.getTileState(BOB_TOKEN);
        assertEq(tileStateBob.lastCooldownStartTime, block.timestamp, "Incorrect last cooldown start time for BOB_TOKEN");
        assertEq(tileStateBob.owner, alice, "BOB_TOKEN should be owned by alice after swap");

        // Fast forward 30 minutes
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod / 2);

        // Bob tries to force swap but fails due to cooldown
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOnCooldown.selector, BOB_TOKEN));
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        // Fast forward another 30 minutes (total 1 hour)
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod / 2);

        // Now Bob can force swap
        vm.prank(bob);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        // Check cooldown times were reset again
        assertEq(pixel8.lastCooldownStartTime(ALICE_TOKEN), block.timestamp);
        assertEq(pixel8.lastCooldownStartTime(BOB_TOKEN), block.timestamp);

        // Verify getTileState() returns correct cooldown start time after final swap
        Pixel8.TileState memory finalTileStateAlice = pixel8.getTileState(ALICE_TOKEN);
        assertEq(finalTileStateAlice.lastCooldownStartTime, block.timestamp, "Incorrect last cooldown start time for ALICE_TOKEN after final swap");
        assertEq(finalTileStateAlice.owner, alice, "ALICE_TOKEN should be owned by alice after final swap");

        Pixel8.TileState memory finalTileStateBob = pixel8.getTileState(BOB_TOKEN);
        assertEq(finalTileStateBob.lastCooldownStartTime, block.timestamp, "Incorrect last cooldown start time for BOB_TOKEN after final swap");
        assertEq(finalTileStateBob.owner, bob, "BOB_TOKEN should be owned by bob after final swap");
    }

    function test_ForceSwap_CannotSwapOwnTokenDuringCooldown() public {
        // Initial force swap to put BOB_TOKEN in cooldown
        vm.prank(alice);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        // Check cooldown times were set
        assertEq(pixel8.lastCooldownStartTime(ALICE_TOKEN), block.timestamp);
        assertEq(pixel8.lastCooldownStartTime(BOB_TOKEN), block.timestamp);

        // Fast forward 30 minutes (ALICE_TOKEN still in cooldown)
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod / 2);

        // Bob should NOT be able to force swap ALICE_TOKEN with Eve's token
        // even though ALICE_TOKEN is in cooldown
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibErrors.TokenOnCooldown.selector, ALICE_TOKEN));
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, EVE_TOKEN);
    }

    function test_ForceSwap_EmitsEvent() public {
        vm.recordLogs();
        
        vm.prank(alice);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 3, "Should emit three events (two transfer + 1 swap)");
        assertEq(entries[2].topics[0], keccak256("ForceSwapped(uint256,uint256)"), "Wrong event signature");
        (uint256 fromTokenId, uint256 toTokenId) = abi.decode(entries[2].data, (uint256, uint256));
        assertEq(fromTokenId, ALICE_TOKEN, "Wrong fromTokenId");
        assertEq(toTokenId, BOB_TOKEN, "Wrong toTokenId");
    }

    function test_ForceSwap_FeeAddedToPrizePool() public {
        uint initialPrizePool = pixel8.getRoyaltiesPrizes().prizePoolPot;
        
        vm.prank(alice);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        uint newPrizePool = pixel8.getRoyaltiesPrizes().prizePoolPot;
        assertEq(newPrizePool, initialPrizePool + _calculateForceSwapFeeMinusDevRoyalties(0.01 ether));
    }

    function test_ForceSwap_MultipleFeesCumulative() public {
        uint initialPrizePool = pixel8.getRoyaltiesPrizes().prizePoolPot;
        
        // First swap
        vm.prank(alice);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);

        // Wait for cooldown
        vm.warp(block.timestamp + pixel8.getForceSwapConfig().cooldownPeriod);

        // Second swap
        vm.prank(bob);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, EVE_TOKEN);

        uint newPrizePool = pixel8.getRoyaltiesPrizes().prizePoolPot;
        assertEq(newPrizePool, initialPrizePool + _calculateForceSwapFeeMinusDevRoyalties(0.02 ether));
    }

    function test_ForceSwap_ExcessFeeAddedToPrizePool() public {
        uint initialPrizePool = pixel8.getRoyaltiesPrizes().prizePoolPot;
        
        vm.prank(alice);
        pixel8.forceSwap{value: 0.015 ether}(ALICE_TOKEN, BOB_TOKEN);

        uint newPrizePool = pixel8.getRoyaltiesPrizes().prizePoolPot;
        assertEq(newPrizePool, initialPrizePool + _calculateForceSwapFeeMinusDevRoyalties(0.015 ether));
    }

    function test_ForceSwap_RevertWhenGameOver() public {
        // Reveal enough tiles to end the game
        vm.startPrank(pool1);
        for (uint i = 1; i <= 10; i++) {
            pixel8.batchMint(alice, i + 10, 1);
        }
        vm.stopPrank();

        vm.startPrank(alice);
        for (uint i = 1; i <= 10; i++) {
            _pixel8_reveal(alice, i + 10, "uri");
        }
        vm.stopPrank();

        assertTrue(pixel8.gameOver(), "Game should be over");

        vm.prank(alice);
        vm.expectRevert(LibErrors.GameOver.selector);
        pixel8.forceSwap{value: 0.01 ether}(ALICE_TOKEN, BOB_TOKEN);
    }

    function _calculateForceSwapFeeMinusDevRoyalties(uint256 _amount) internal view returns (uint256) {
        uint96 devFeeBips = pixel8.getDevRoyaltyConfig().feeBips;
        uint96 creatorFeeBips = pixel8.getCreatorRoyaltyConfig().feeBips;
        uint96 prizePoolFeeBips = pixel8.getPrizePoolFeeBips();
        uint totalBips = devFeeBips + creatorFeeBips + prizePoolFeeBips;
        return _amount - (_amount * (devFeeBips + creatorFeeBips) / totalBips);
    }
} 