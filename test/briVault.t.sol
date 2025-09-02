// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BriVault} from "../src/briVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract BriVaultTest is Test {
    uint256 public participationFeeBsp;
    uint256 public eventStartDate;
    uint256 public eventEndDate;
    address public participationFeeAddress;
    uint256 public minimumAmount;

    // Vault contract
    BriVault public briVault;

    // Users
    address owner = address(0x0123456);
    address user1 = makeAddr("user1");

    string[48] countries = [
        "United States", "Canada", "Mexico", "Argentina", "Brazil", "Ecuador",
        "Uruguay", "Colombia", "Peru", "Chile", "Japan", "South Korea",
        "Australia", "Iran", "Saudi Arabia", "Qatar", "Uzbekistan", "Jordan",
        "France", "Germany", "Spain", "Portugal", "England", "Netherlands",
        "Italy", "Croatia", "Belgium", "Switzerland", "Denmark", "Poland",
        "Serbia", "Sweden", "Austria", "Morocco", "Senegal", "Nigeria",
        "Cameroon", "Egypt", "South Africa", "Ghana", "Algeria", "Tunisia",
        "Ivory Coast", "New Zealand", "Costa Rica", "Panama", "United Arab Emirates", "Iraq"
    ];

    function setUp() public {
        participationFeeBsp = 0.0005 ether;
        eventStartDate = block.timestamp + 2 days;
        eventEndDate = eventStartDate + 31 days;
        participationFeeAddress = address(0x12345);
        minimumAmount = 0.0002 ether;

        vm.startPrank(owner);
        briVault = new BriVault(
            IERC20(address(0)), // replace `address(0)` with actual _asset address
            participationFeeBsp,
            eventStartDate,
            participationFeeAddress,
            minimumAmount,
            eventEndDate
        );
        vm.stopPrank();
    }

    function testSetCountryOnlyOwner() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        string memory result = briVault.getCountry(2);
        assertEq(result, "Mexico");
    }

    function testOwnerIsSetCorrectly() public view {
    assertEq(briVault.owner(), owner, "Owner should be deployer");
    }

    function testNotOwnerCannotSetCountry() public {
        vm.prank(user1);
        vm.expectRevert();
        briVault.setCountry(countries);
    }

    function testSetWinner() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.warp(eventEndDate + 1);
        string memory winner = briVault.setWinner(2);
        console.log(winner);
        string memory result = briVault.getWinner();
        console.log(result);
        assertEq(result, "Mexico");
    }
}