// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol, decimals) {}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}
