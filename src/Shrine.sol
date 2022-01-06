// SPDX-License-Identifier: AGPL-3.0
/**
                                                                                                      
                                                                                                      
           .o.                    .                            .o8                                    
          .888.                 .o8                           "888                                    
         .8"888.      .oooo.o .o888oo oooo d8b  .ooooo.   .oooo888  oooo d8b  .ooooo.  oo.ooooo.      
        .8' `888.    d88(  "8   888   `888""8P d88' `88b d88' `888  `888""8P d88' `88b  888' `88b     
       .88ooo8888.   `"Y88b.    888    888     888   888 888   888   888     888   888  888   888     
      .8'     `888.  o.  )88b   888 .  888     888   888 888   888   888     888   888  888   888     
     o88o     o8888o 8""888P'   "888" d888b    `Y8bod8P' `Y8bod88P" d888b    `Y8bod8P'  888bod8P'     
                                                                                        888           
                                                                                       o888o          
                                                                                                      
                                                                                                      
 */
pragma solidity ^0.8.11;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Ownable} from "./lib/Ownable.sol";
import {ReentrancyGuard} from "./lib/ReentrancyGuard.sol";

/// @title Shrine
/// @notice A Shrine maintains a list of Champions with individual weights (shares), and anyone could
/// offer any ERC-20 tokens to the Shrine in order to distribute them to the Champions proportional to their
/// shares. A Champion transfer their right to claim all future tokens offered to
/// the Champion to another address.
contract Shrine is Ownable, ReentrancyGuard {
    error Shrine_AlreadyInitialized();
    error Shrine_InputArraysLengthMismatch();
    error Shrine_NotAuthorized();
    error Shrine_InvalidMerkleProof();

    type Champion is address;
    type Version is uint256;

    using SafeTransferLib for ERC20;

    event Offer(address indexed sender, ERC20 indexed token, uint256 amount);
    event Claim(
        Version indexed version,
        ERC20 indexed token,
        Champion indexed champion,
        uint256 claimedTokenAmount
    );
    event ClaimFromMetaShrine(Shrine indexed metaShrine);
    event TransferChampionStatus(Champion indexed champion, address recipient);
    event UpdateLedger(
        Version indexed newVersion,
        Ledger newLedger
    );
    event UpdateLedgerMetadata(
        Version indexed version,
        string newLedgerMetadataIPFSHash
    );

    struct Ledger {
        bytes32 merkleRoot;
        uint256 totalShares;
    }

    /// @notice The current version of the ledger, starting from 1
    Version public currentLedgerVersion;

    /// @notice version => ledger
    mapping(Version => Ledger) public ledgerOfVersion;

    /// @notice version => (token => (champion => claimedTokens))
    mapping(Version => mapping(ERC20 => mapping(Champion => uint256)))
        public claimedTokens;

    /// @notice version => (token => offeredTokens)
    mapping(Version => mapping(ERC20 => uint256)) public offeredTokens;

    /// @notice champion => address
    mapping(Champion => address) public championClaimRightOwner;

    function initialize(
        address initialGuardian,
        Ledger calldata initialLedger,
        string calldata initialLedgerMetadataIPFSHash
    )
        external
    {
        // we use currentLedgerVersion as a flag for whether the Shrine
        // has already been initialized
        if (Version.unwrap(currentLedgerVersion) != 0) {
            revert Shrine_AlreadyInitialized();
        }

        __ReentrancyGuard_init();
        __Ownable_init(initialGuardian);

        // the version number start at 1
        currentLedgerVersion = Version.wrap(1);
        ledgerOfVersion[Version.wrap(1)] = initialLedger;

        // emit event to let indexers pick up ledger & metadata IPFS hash
        emit UpdateLedger(Version.wrap(1), initialLedger);
        emit UpdateLedgerMetadata(Version.wrap(1), initialLedgerMetadataIPFSHash);
    }

    /**
                                                                                                    
                                 ___   ____________________  _   _______                            
                                /   | / ____/_  __/  _/ __ \/ | / / ___/                            
                               / /| |/ /     / /  / // / / /  |/ /\__ \                             
                              / ___ / /___  / / _/ // /_/ / /|  /___/ /                             
                             /_/  |_\____/ /_/ /___/\____/_/ |_//____/                              
                                                                                                    
     */

    /// @notice Offer ERC-20 tokens to the Shrine and distribute them to Champions proportional
    /// to their shares in the Shrine. Callable by anyone.
    /// @param token The ERC-20 token being offered to the Shrine
    /// @param amount The amount of tokens to offer
    function offer(ERC20 token, uint256 amount) external {
        // -------------------------------------------------------------------
        // State updates
        // -------------------------------------------------------------------

        // distribute tokens to Champions
        offeredTokens[currentLedgerVersion][token] += amount;

        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        // transfer tokens from sender
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Offer(msg.sender, token, amount);
    }

    /// @notice A Champion or the owner of a Champion may call this to claim their share of the tokens offered to this Shrine.
    /// Requires a Merkle proof to prove that the Champion is part of this Shrine's Merkle tree.
    /// Only callable by the champion (if the right was never transferred) or the owner
    /// (that the original champion transferred their rights to)
    /// @param version The Merkle tree version
    /// @param token The ERC-20 token to be claimed
    /// @param champion The Champion address. If the Champion rights have been transferred, the tokens will be sent to its owner.
    /// @param shares The share amount of the Champion
    /// @param merkleProof The Merkle proof showing the Champion is part of this Shrine's Merkle tree
    /// @return claimedTokenAmount The amount of tokens claimed
    function claim(
        Version version,
        ERC20 token,
        Champion champion,
        uint256 shares,
        bytes32[] calldata merkleProof
    ) external returns (uint256 claimedTokenAmount) {
        return _claim(version, token, champion, shares, merkleProof);
    }

    /// @notice A variant of {claim} that combines multiple claims into a single call.
    function claimMultiple(
        Version[] calldata versionList,
        ERC20[] calldata tokenList,
        Champion[] calldata championList,
        uint256[] calldata sharesList,
        bytes32[][] calldata merkleProofList
    ) external returns (uint256[] memory claimedTokenAmountList) {
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        if (
            versionList.length != tokenList.length ||
            versionList.length != championList.length ||
            versionList.length != sharesList.length ||
            versionList.length != merkleProofList.length
        ) {
            revert Shrine_InputArraysLengthMismatch();
        }

        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        claimedTokenAmountList = new uint256[](versionList.length);
        for (uint256 i = 0; i < versionList.length; i++) {
            claimedTokenAmountList[i] = _claim(
                versionList[i],
                tokenList[i],
                championList[i],
                sharesList[i],
                merkleProofList[i]
            );
        }
    }

    /// @notice A variant of {claim} that combines multiple claims for the same Champion & version into a single call.
    /// @dev This is more efficient than {claimMultiple} since it only checks Champion ownership & verifies Merkle proof once.
    function claimMultipleTokensForChampion(
        Version version,
        ERC20[] calldata tokenList,
        Champion champion,
        uint256 shares,
        bytes32[] calldata merkleProof
    ) external returns (uint256[] memory claimedTokenAmountList) {
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        // verify sender auth
        _verifyChampionOwnership(champion);

        // verify Merkle proof that the champion is part of the Merkle tree
        _verifyMerkleProof(version, champion, shares, merkleProof);

        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        // transfer tokens
        claimedTokenAmountList = new uint256[](tokenList.length);
        for (uint256 i = 0; i < tokenList.length; i++) {
            // compute claimable amount
            claimedTokenAmountList[i] = computeClaimableTokenAmount(
                version,
                tokenList[i],
                champion,
                shares
            );

            // transfer tokens to the sender
            tokenList[i].safeTransfer(msg.sender, claimedTokenAmountList[i]);

            emit Claim(
                version,
                tokenList[i],
                champion,
                claimedTokenAmountList[i]
            );
        }
    }

    /// @notice If this Shrine is a Champion of another Shrine (MetaShrine), calling this can claim the tokens
    /// from the MetaShrine and distribute them to this Shrine's Champions. Callable by anyone.
    /// @param version The Merkle tree version
    /// @param token The ERC-20 token to be claimed
    /// @param shares The share amount of the Champion
    /// @param merkleProof The Merkle proof showing the Champion is part of this Shrine's Merkle tree
    /// @return claimedTokenAmount The amount of tokens claimed
    function claimFromMetaShrine(
        Shrine metaShrine,
        Version version,
        ERC20 token,
        uint256 shares,
        bytes32[] calldata merkleProof
    ) external nonReentrant returns (uint256 claimedTokenAmount) {
        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        // claim tokens from the meta shrine
        uint256 beforeBalance = token.balanceOf(address(this));
        metaShrine.claim(
            version,
            token,
            Champion.wrap(address(this)),
            shares,
            merkleProof
        );
        claimedTokenAmount = token.balanceOf(address(this)) - beforeBalance;

        // -------------------------------------------------------------------
        // State updates
        // -------------------------------------------------------------------

        // distribute tokens to Champions
        offeredTokens[currentLedgerVersion][token] += claimedTokenAmount;

        emit Offer(address(metaShrine), token, claimedTokenAmount);
        emit ClaimFromMetaShrine(metaShrine);
    }

    /// @notice A variant of {claimFromMetaShrine} that combines multiple claims into a single call.
    function claimMultipleFromMetaShrine(
        Shrine metaShrine,
        Version[] calldata versionList,
        ERC20[] calldata tokenList,
        uint256[] calldata sharesList,
        bytes32[][] calldata merkleProofList
    ) external nonReentrant returns (uint256[] memory claimedTokenAmountList) {
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        if (
            versionList.length != tokenList.length ||
            versionList.length != sharesList.length ||
            versionList.length != merkleProofList.length
        ) {
            revert Shrine_InputArraysLengthMismatch();
        }

        // claim and distribute tokens
        claimedTokenAmountList = new uint256[](versionList.length);
        for (uint256 i = 0; i < versionList.length; i++) {
            // -------------------------------------------------------------------
            // Effects
            // -------------------------------------------------------------------

            // claim tokens from the meta shrine
            uint256 beforeBalance = tokenList[i].balanceOf(address(this));
            metaShrine.claim(
                versionList[i],
                tokenList[i],
                Champion.wrap(address(this)),
                sharesList[i],
                merkleProofList[i]
            );
            claimedTokenAmountList[i] =
                tokenList[i].balanceOf(address(this)) -
                beforeBalance;

            // -------------------------------------------------------------------
            // State updates
            // -------------------------------------------------------------------

            // distribute tokens to Champions
            offeredTokens[currentLedgerVersion][
                tokenList[i]
            ] += claimedTokenAmountList[i];

            emit Offer(
                address(metaShrine),
                tokenList[i],
                claimedTokenAmountList[i]
            );
        }
        emit ClaimFromMetaShrine(metaShrine);
    }

    /// @notice Allows a champion to transfer their right to claim from this shrine to
    /// another address. The champion will effectively lose their shrine membership, so
    /// make sure the new owner is a trusted party.
    /// Only callable by the champion (if the right was never transferred) or the owner
    /// (that the original champion transferred their rights to)
    /// @notice champion The champion whose claim rights will be transferred away
    /// @notice newOwner The address that will receive all rights of the champion
    function transferChampionClaimRight(Champion champion, address newOwner)
        external
    {
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        // verify sender auth
        _verifyChampionOwnership(champion);

        // -------------------------------------------------------------------
        // State updates
        // -------------------------------------------------------------------

        championClaimRightOwner[champion] = newOwner;
        emit TransferChampionStatus(champion, newOwner);
    }

    /**
                                                                                                    
                               __________________________________  _____                            
                              / ____/ ____/_  __/_  __/ ____/ __ \/ ___/                            
                             / / __/ __/   / /   / / / __/ / /_/ /\__ \                             
                            / /_/ / /___  / /   / / / /___/ _, _/___/ /                             
                            \____/_____/ /_/   /_/ /_____/_/ |_|/____/                              
                                                                                                    
    */

    /// @notice Computes the amount of a particular ERC-20 token claimable by a Champion from
    /// a particular version of the Merkle tree.
    /// @param version The Merkle tree version
    /// @param token The ERC-20 token to be claimed
    /// @param champion The Champion address
    /// @param shares The share amount of the Champion
    function computeClaimableTokenAmount(
        Version version,
        ERC20 token,
        Champion champion,
        uint256 shares
    ) public view returns (uint256 claimableTokenAmount) {
        uint256 totalShares = ledgerOfVersion[version].totalShares;
        uint256 offeredTokenAmount = (offeredTokens[version][token] * shares) /
            totalShares;
        uint256 claimedTokenAmount = claimedTokens[version][token][champion];
        // rounding may cause (offeredTokenAmount < claimedTokenAmount)
        // don't want to revert because of it
        claimableTokenAmount = offeredTokenAmount >= claimedTokenAmount
            ? offeredTokenAmount - claimedTokenAmount
            : 0;
    }

    /// @notice The Shrine Guardian's address (same as the contract owner)
    function guardian() external view returns (address) {
        return owner();
    }

    /**
                                                                                                    
                ____  _   ______  __   ________  _____    ____  ____  _______    _   __             
               / __ \/ | / / /\ \/ /  / ____/ / / /   |  / __ \/ __ \/  _/   |  / | / /             
              / / / /  |/ / /  \  /  / / __/ / / / /| | / /_/ / / / // // /| | /  |/ /              
             / /_/ / /|  / /___/ /  / /_/ / /_/ / ___ |/ _, _/ /_/ // // ___ |/ /|  /               
             \____/_/ |_/_____/_/   \____/\____/_/  |_/_/ |_/_____/___/_/  |_/_/ |_/                
                                                                                                    
     */

    /// @notice The Guardian may call this function to update the ledger, so that the list of
    /// champions and the associated weights are updated.
    /// @param newLedger The new Merkle tree to use for the list of champions and their shares
    function updateLedger(Ledger calldata newLedger)
        external
        onlyOwner
    {
        Version newVersion = Version.wrap(
            Version.unwrap(currentLedgerVersion) + 1
        );
        currentLedgerVersion = newVersion;
        ledgerOfVersion[newVersion] = newLedger;

        emit UpdateLedger(
            newVersion,
            newLedger
        );
    }

    /// @notice The Guardian may call this function to update the ledger metadata IPFS hash.
    /// @dev This function simply emits the IPFS hash in an event, so that an off-chain indexer
    /// can pick it up.
    /// @param newLedgerMetadataIPFSHash The IPFS hash of the updated metadata
    function updateLedgerMetadata(Version version, string calldata newLedgerMetadataIPFSHash)
        external
        onlyOwner
    {
        emit UpdateLedgerMetadata(version, newLedgerMetadataIPFSHash);
    }

    /**
                                                                                                    
                           _____   __________________  _   _____    __   _____                      
                          /  _/ | / /_  __/ ____/ __ \/ | / /   |  / /  / ___/                      
                          / //  |/ / / / / __/ / /_/ /  |/ / /| | / /   \__ \                       
                        _/ // /|  / / / / /___/ _, _/ /|  / ___ |/ /______/ /                       
                       /___/_/ |_/ /_/ /_____/_/ |_/_/ |_/_/  |_/_____/____/                        
                                                                                                    
     */

    /// @dev Reverts if the sender isn't the champion or does not own the champion claim right
    /// @param champion The champion whose ownership will be verified
    function _verifyChampionOwnership(Champion champion) internal view {
        {
            address _championClaimRightOwner = championClaimRightOwner[
                champion
            ];
            if (_championClaimRightOwner == address(0)) {
                // claim right not transferred, sender should be the champion
                if (msg.sender != Champion.unwrap(champion)) revert Shrine_NotAuthorized();
            } else {
                // claim right transferred, sender should be the owner
                if (msg.sender != _championClaimRightOwner) revert Shrine_NotAuthorized();
            }
        }
    }

    /// @dev Reverts if the champion is not part of the Merkle tree
    /// @param version The Merkle tree version
    /// @param champion The Champion address. If the Champion rights have been transferred, the tokens will be sent to its owner.
    /// @param shares The share amount of the Champion
    /// @param merkleProof The Merkle proof showing the Champion is part of this Shrine's Merkle tree
    function _verifyMerkleProof(
        Version version,
        Champion champion,
        uint256 shares,
        bytes32[] calldata merkleProof
    ) internal view {
        if (
            !MerkleProof.verify(
                merkleProof,
                ledgerOfVersion[version].merkleRoot,
                keccak256(abi.encodePacked(champion, shares))
            )
        ) {
            revert Shrine_InvalidMerkleProof();
        }
    }

    /// @dev See {claim}
    function _claim(
        Version version,
        ERC20 token,
        Champion champion,
        uint256 shares,
        bytes32[] calldata merkleProof
    ) internal returns (uint256 claimedTokenAmount) {
        // -------------------------------------------------------------------
        // Validation
        // -------------------------------------------------------------------

        // verify sender auth
        _verifyChampionOwnership(champion);

        // verify Merkle proof that the champion is part of the Merkle tree
        _verifyMerkleProof(version, champion, shares, merkleProof);

        // compute claimable amount
        claimedTokenAmount = computeClaimableTokenAmount(
            version,
            token,
            champion,
            shares
        );

        // -------------------------------------------------------------------
        // Effects
        // -------------------------------------------------------------------

        // transfer tokens to the sender
        token.safeTransfer(msg.sender, claimedTokenAmount);

        emit Claim(version, token, champion, claimedTokenAmount);
    }
}
