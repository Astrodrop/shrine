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

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Shrine} from "./Shrine.sol";

contract ShrineFactory {
    using Clones for address;

    event CreateShrine(
        address indexed creator,
        address indexed guardian,
        Shrine indexed shrine,
        Shrine.Ledger ledger
    );

    /// @notice The Shrine template contract used by the minimal proxies
    Shrine public immutable shrineTemplate;

    constructor(Shrine shrineTemplate_) {
        shrineTemplate = shrineTemplate_;
    }

    /// @notice Creates a Shrine given an initial ledger with the distribution shares.
    /// @param guardian The Shrine's initial guardian, who controls the ledger
    /// @param ledger The Shrine's initial ledger with the distribution shares
    function createShrine(address guardian, Shrine.Ledger calldata ledger)
        external
        returns (Shrine shrine)
    {
        shrine = Shrine(address(shrineTemplate).clone());

        shrine.initialize(guardian, ledger);

        emit CreateShrine(msg.sender, guardian, shrine, ledger);
    }

    /// @notice Creates a Shrine given an initial ledger with the distribution shares.
    /// Uses CREATE2 so that the Shrine's address can be computed deterministically
    /// using predictAddress().
    /// @param guardian The Shrine's initial guardian, who controls the ledger
    /// @param ledger The Shrine's initial ledger with the distribution shares
    function createShrineDeterministic(
        address guardian,
        Shrine.Ledger calldata ledger,
        bytes32 salt
    ) external returns (Shrine shrine) {
        shrine = Shrine(address(shrineTemplate).cloneDeterministic(salt));

        shrine.initialize(guardian, ledger);

        emit CreateShrine(msg.sender, guardian, shrine, ledger);
    }

    /// @notice Predicts the address of a Shrine deployed using CREATE2, given the salt value.
    /// @param salt The salt value used by CREATE2
    function predictAddress(bytes32 salt)
        external
        view
        returns (address pairAddress)
    {
        return address(shrineTemplate).predictDeterministicAddress(salt);
    }
}
