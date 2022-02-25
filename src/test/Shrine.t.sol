// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {DSTest} from "ds-test/test.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Shrine} from "../Shrine.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ShrineFactory} from "../ShrineFactory.sol";
import {MerkleTreeGenerator} from "./lib/MerkleTreeGenerator.sol";

contract ShrineTest is DSTest, MerkleTreeGenerator {
    uint256 constant EXAMPLE_TOTAL_SHARES = 1e18;
    uint256 constant EXAMPLE_USER_SHARES = 7e16;

    ShrineFactory factory;
    MockERC20 exampleToken;

    Shrine exampleShrine;
    bytes32[] exampleProof;

    function setUp() public {
        Shrine template = new Shrine();
        factory = new ShrineFactory(template);
        exampleToken = new MockERC20("Test Token", "TOK", 18);

        // generate example Merkle tree
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(
            keccak256(abi.encodePacked(address(this), EXAMPLE_USER_SHARES)),
            10,
            keccak256(abi.encodePacked(block.timestamp))
        );
        exampleProof = proof;

        // generate example shrine
        exampleShrine = factory.createShrine(
            address(this),
            Shrine.Ledger({
                merkleRoot: root,
                totalShares: EXAMPLE_TOTAL_SHARES
            }),
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC"
        );

        // mint mock tokens to self
        exampleToken.mint(type(uint256).max);

        // set token approvals
        exampleToken.approve(address(exampleShrine), type(uint256).max);

        // offer example token
        exampleShrine.offer(exampleToken, type(uint128).max);
    }

    /// -------------------------------------------------------------------
    /// Gas benchmarking
    /// -------------------------------------------------------------------

    function testGas_offer(uint128 amount) public {
        exampleShrine.offer(exampleToken, amount);
    }

    function testGas_claim() public {
        Shrine.ClaimInfo memory claimInfo = Shrine.ClaimInfo({
            version: Shrine.Version.wrap(1),
            token: exampleToken,
            champion: Shrine.Champion.wrap(address(this)),
            shares: EXAMPLE_USER_SHARES,
            merkleProof: exampleProof
        });
        exampleShrine.claim(address(this), claimInfo);
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_offerAndClaim(
        uint128 offerAmount,
        uint128 userShareAmount,
        uint8 treeHeightMinusOne,
        bytes32 randomness
    ) public {
        if (offerAmount == 0) offerAmount = 1;
        if (treeHeightMinusOne == 0) treeHeightMinusOne = 1;
        if (userShareAmount == 0) userShareAmount = 1;

        // setup
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(
            keccak256(
                abi.encodePacked(address(this), uint256(userShareAmount))
            ),
            treeHeightMinusOne,
            randomness
        );
        Shrine shrine = factory.createShrine(
            address(this),
            Shrine.Ledger({merkleRoot: root, totalShares: userShareAmount}),
            ""
        );
        MockERC20 testToken = new MockERC20("Test Token", "TOK", 18);

        // mint and offer tokens
        testToken.mint(offerAmount);
        testToken.approve(address(shrine), offerAmount);
        shrine.offer(testToken, offerAmount);

        // claim tokens
        Shrine.ClaimInfo memory claimInfo = Shrine.ClaimInfo({
            version: Shrine.Version.wrap(1),
            token: testToken,
            champion: Shrine.Champion.wrap(address(this)),
            shares: userShareAmount,
            merkleProof: proof
        });
        uint256 claimedTokenAmount = shrine.claim(address(this), claimInfo);

        // verify tokens claimed
        assertEq(testToken.balanceOf(address(this)), offerAmount);
        assertEq(claimedTokenAmount, offerAmount);

        // try claiming again
        claimedTokenAmount = shrine.claim(address(this), claimInfo);

        // verify tokens claimed
        assertEq(testToken.balanceOf(address(this)), offerAmount);
        assertEq(claimedTokenAmount, 0);
    }

    function testCorrectness_offerAndClaimMultipleTokensForChampion(
        uint128[] calldata offerAmountList,
        uint128 userShareAmount,
        uint8 treeHeightMinusOne,
        bytes32 randomness
    ) public {
        if (offerAmountList.length == 0) return;
        if (treeHeightMinusOne == 0) treeHeightMinusOne = 1;
        if (userShareAmount == 0) userShareAmount = 1;

        // setup
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(
            keccak256(
                abi.encodePacked(address(this), uint256(userShareAmount))
            ),
            treeHeightMinusOne,
            randomness
        );
        Shrine shrine = factory.createShrine(
            address(this),
            Shrine.Ledger({merkleRoot: root, totalShares: userShareAmount}),
            ""
        );
        ERC20[] memory testTokenList = new ERC20[](offerAmountList.length);
        for (uint256 i = 0; i < offerAmountList.length; i++) {
            MockERC20 testToken = new MockERC20("Test Token", "TOK", 18);
            testTokenList[i] = ERC20(address(testToken));

            // mint and offer tokens
            testToken.mint(offerAmountList[i]);
            testTokenList[i].approve(address(shrine), offerAmountList[i]);
            shrine.offer(testTokenList[i], offerAmountList[i]);
        }

        // claim tokens
        uint256[] memory claimedTokenAmountList = shrine
            .claimMultipleTokensForChampion(
                address(this),
                Shrine.Version.wrap(1),
                testTokenList,
                Shrine.Champion.wrap(address(this)),
                userShareAmount,
                proof
            );

        // verify tokens claimed
        for (uint256 i = 0; i < offerAmountList.length; i++) {
            assertEq(
                testTokenList[i].balanceOf(address(this)),
                offerAmountList[i]
            );
            assertEq(claimedTokenAmountList[i], offerAmountList[i]);
        }

        // try claiming again
        claimedTokenAmountList = shrine.claimMultipleTokensForChampion(
            address(this),
            Shrine.Version.wrap(1),
            testTokenList,
            Shrine.Champion.wrap(address(this)),
            userShareAmount,
            proof
        );

        // verify tokens claimed
        for (uint256 i = 0; i < offerAmountList.length; i++) {
            assertEq(
                testTokenList[i].balanceOf(address(this)),
                offerAmountList[i]
            );
            assertEq(claimedTokenAmountList[i], 0);
        }
    }

    function testCorrectness_offerAndClaimFromMetaShrine(
        uint128 offerAmount,
        uint128 userShareAmount,
        uint8 treeHeightMinusOne,
        bytes32 randomness
    ) public {
        if (offerAmount == 0) offerAmount = 1;
        if (treeHeightMinusOne == 0) treeHeightMinusOne = 1;
        if (userShareAmount == 0) userShareAmount = 1;

        // setup
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(
            keccak256(
                abi.encodePacked(address(this), uint256(userShareAmount))
            ),
            treeHeightMinusOne,
            randomness
        );
        Shrine shrine = factory.createShrine(
            address(this),
            Shrine.Ledger({merkleRoot: root, totalShares: userShareAmount}),
            ""
        );
        (bytes32 metaRoot, bytes32[] memory metaProof) = generateMerkleTree(
            keccak256(
                abi.encodePacked(address(shrine), uint256(userShareAmount))
            ),
            treeHeightMinusOne,
            randomness
        );
        Shrine metaShrine = factory.createShrine(
            address(this),
            Shrine.Ledger({merkleRoot: metaRoot, totalShares: userShareAmount}),
            ""
        );
        MockERC20 testToken = new MockERC20("Test Token", "TOK", 18);

        // mint and offer tokens to meta shrine
        testToken.mint(offerAmount);
        testToken.approve(address(metaShrine), offerAmount);
        metaShrine.offer(testToken, offerAmount);

        // claim tokens from meta shrine to shrine
        Shrine.MetaShrineClaimInfo memory metaClaimInfo = Shrine
            .MetaShrineClaimInfo({
                metaShrine: metaShrine,
                version: Shrine.Version.wrap(1),
                token: testToken,
                shares: userShareAmount,
                merkleProof: metaProof
            });
        shrine.claimFromMetaShrine(metaClaimInfo);

        // claim tokens from shrine
        Shrine.ClaimInfo memory claimInfo = Shrine.ClaimInfo({
            version: Shrine.Version.wrap(1),
            token: testToken,
            champion: Shrine.Champion.wrap(address(this)),
            shares: userShareAmount,
            merkleProof: proof
        });
        uint256 claimedTokenAmount = shrine.claim(address(this), claimInfo);

        // verify tokens claimed
        assertEq(testToken.balanceOf(address(this)), offerAmount);
        assertEq(claimedTokenAmount, offerAmount);
    }
}
