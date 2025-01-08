// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { console2 as c } from "forge-std/Test.sol";
import { LibErrors } from "src/LibErrors.sol";
import { TestBase01 } from "../utils/TestBase01.sol";
import { Factory } from "src/Factory.sol";
import { IPixel8 } from "src/IPixel8.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { PoolCurve } from "src/Common.sol";
import { Auth } from "src/Auth.sol";

contract FactoryTest is TestBase01 {
    Factory public factory;
    MintSwapPool public pool;

    function setUp() public override {
        super.setUp();
        factory = new Factory(authoriser1);
        pool = new MintSwapPool(owner1, address(factory));
    }

    function test_createPixel8_Success() public {
        Pixel8.Config memory config = _getDefaultPixel8Config();
        PoolCurve memory curve = PoolCurve({
            mintStartId: 1,
            mintEndId: 100,
            startPriceWei: 1 ether,
            delta: 1.1 ether
        });

        Auth.Signature memory sig = _computeAuthoriserSig(
            factory.getCreatePixel8SignableData(config, curve),
            block.timestamp + 1 hours
        );

        address pixel8Address = factory.createPixel8(
            address(pool),
            config,
            curve,
            sig
        );

        // Verify the Pixel8 instance was created
        assertTrue(pixel8Address != address(0));
        Pixel8 newPixel8 = Pixel8(payable(pixel8Address));

        // Verify config was set correctly
        assertEq(newPixel8.owner(), address(factory));
        assertEq(newPixel8.authoriser(), authoriser1);
        assertEq(newPixel8.pool(), address(pool));
        assertEq(newPixel8.defaultImage(), "img");
        assertEq(newPixel8.name(), "Pixel8");
        assertEq(newPixel8.symbol(), "PIXEL8");
        assertEq(pool.poolIds(address(newPixel8)), 1);
        (IPixel8 retNft, PoolCurve memory retCurve, ,) = pool.pools(1);
        assertEq(address(retNft), address(newPixel8));
        assertEq(retCurve.mintStartId, 1);
        assertEq(retCurve.mintEndId, 100);
        assertEq(retCurve.startPriceWei, 1 ether);
        assertEq(retCurve.delta, 1.1 ether);
    }

    function test_createPixel8_InvalidSignature() public {
        Pixel8.Config memory config = _getDefaultPixel8Config();
        PoolCurve memory curve = PoolCurve({
            mintStartId: 1,
            mintEndId: 100,
            startPriceWei: 1 ether,
            delta: 1.1 ether
        });

        // Create signature with wrong signer
        Auth.Signature memory sig = _computeOwnerSig(
            abi.encode(config, curve),
            block.timestamp + 1 hours
        );

        vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, address(this)));
        factory.createPixel8(
            address(pool),
            config,
            curve,
            sig
        );
    }

    function test_createPixel8_ExpiredSignature() public {
        Pixel8.Config memory config = _getDefaultPixel8Config();
        PoolCurve memory curve = PoolCurve({
            mintStartId: 1,
            mintEndId: 100,
            startPriceWei: 1 ether,
            delta: 1.1 ether
        });

        Auth.Signature memory sig = _computeAuthoriserSig(
            abi.encode(config, curve),
            block.timestamp - 1 // Expired
        );

        vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureExpired.selector, address(this)));
        factory.createPixel8(
            address(pool),
            config,
            curve,
            sig
        );
    }

    function test_createPixel8_ModifiedParameterSignature() public {
        Pixel8.Config memory config = _getDefaultPixel8Config();
        PoolCurve memory curve = PoolCurve({
            mintStartId: 1,
            mintEndId: 100,
            startPriceWei: 1 ether,
            delta: 1.1 ether
        });

        Auth.Signature memory sig = _computeAuthoriserSig(
            abi.encode(config, curve),
            block.timestamp + 1 hours
        );

        // Modify config after signature was computed
        config.owner = address(0xdead);

        vm.expectRevert(abi.encodeWithSelector(LibErrors.SignatureInvalid.selector, address(this)));
        factory.createPixel8(
            address(pool),
            config,
            curve,
            sig
        );
    }

} 