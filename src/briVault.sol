// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BriVault is ERC4626 {
    constructor (IERC20 _asset) ERC4626 (_asset) ERC20("BriTechLabs", "BTT") {

    }

}
