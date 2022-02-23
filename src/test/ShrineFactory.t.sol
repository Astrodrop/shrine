// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {DSTest} from "ds-test/test.sol";

import {Shrine} from "../Shrine.sol";
import {ShrineFactory} from "../ShrineFactory.sol";

contract ShrineFactoryTest is DSTest {
    ShrineFactory factory;

    function setUp() public {
        Shrine template = new Shrine();
        factory = new ShrineFactory(template);
    }

    /// -------------------------------------------------------------------
    /// Gas benchmarking
    /// -------------------------------------------------------------------

    function testGas_createShrine(
        address guardian,
        Shrine.Ledger calldata ledger
    ) public {
        if (ledger.totalShares == 0) return;
        factory.createShrine(
            guardian,
            ledger,
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC"
        );
    }

    function testGas_createShrineDeterministic(
        address guardian,
        Shrine.Ledger calldata ledger,
        bytes32 salt
    ) public {
        if (ledger.totalShares == 0) return;
        factory.createShrineDeterministic(
            guardian,
            ledger,
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC",
            salt
        );
    }

    function testGas_predictAddress(bytes32 salt) public view {
        factory.predictAddress(salt);
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_createShrine(
        address guardian,
        Shrine.Ledger calldata ledger
    ) public {
        if (ledger.totalShares == 0) return;
        Shrine shrine = factory.createShrine(
            guardian,
            ledger,
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC"
        );
        assertEq(shrine.guardian(), guardian);
        Shrine.Ledger memory storedLedger = shrine.getLedgerOfVersion(
            Shrine.Version.wrap(1)
        );
        assertEq(storedLedger.merkleRoot, ledger.merkleRoot);
        assertEq(storedLedger.totalShares, ledger.totalShares);
    }

    function testCorrectness_createShrineDeterministic(
        address guardian,
        Shrine.Ledger calldata ledger,
        bytes32 salt
    ) public {
        if (ledger.totalShares == 0) return;
        Shrine shrine = factory.createShrineDeterministic(
            guardian,
            ledger,
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC",
            salt
        );
        assertEq(shrine.guardian(), guardian);
        Shrine.Ledger memory storedLedger = shrine.getLedgerOfVersion(
            Shrine.Version.wrap(1)
        );
        assertEq(storedLedger.merkleRoot, ledger.merkleRoot);
        assertEq(storedLedger.totalShares, ledger.totalShares);
    }

    function testCorrectness_predictAddress(
        address guardian,
        Shrine.Ledger calldata ledger,
        bytes32 salt
    ) public {
        if (ledger.totalShares == 0) return;
        Shrine shrine = factory.createShrineDeterministic(
            guardian,
            ledger,
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC",
            salt
        );
        address predictedAddress = factory.predictAddress(salt);
        assertEq(predictedAddress, address(shrine));
    }
}
