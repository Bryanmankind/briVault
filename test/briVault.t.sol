// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BriVault} from "../src/briVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockErc20.t.sol";


contract BriVaultTest is Test {
    uint256 public participationFeeBsp;
    uint256 public eventStartDate;
    uint256 public eventEndDate;
    address public participationFeeAddress;
    uint256 public minimumAmount;

    // Vault contract
    BriVault public briVault;
    MockERC20 public mockToken;

    // Users
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");

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
        participationFeeBsp = 150; // 1.5%
        eventStartDate = block.timestamp + 2 days;
        eventEndDate = eventStartDate + 31 days;
        participationFeeAddress = makeAddr("participationFeeAddress");
        minimumAmount = 0.0002 ether;

        mockToken = new MockERC20("Mock Token", "MTK");

        mockToken.mint(owner, 20 ether);
        mockToken.mint(user1, 20 ether);
        mockToken.mint(user2, 20 ether);
        mockToken.mint(user3, 20 ether);
        mockToken.mint(user4, 20 ether);
        mockToken.mint(user5, 20 ether);

        vm.startPrank(owner);
        briVault = new BriVault(
            IERC20(address(mockToken)), // replace `address(0)` with actual _asset address
            participationFeeBsp,
            eventStartDate,
            participationFeeAddress,
            minimumAmount,
            eventEndDate
        );

        briVault.approve(address(mockToken), type(uint256).max);

          vm.stopPrank();
    }

    function testSetCountryOnlyOwner() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        string memory result = briVault.getCountry(2);
        assertEq(result, "Mexico");
    }

    function testSetCountryNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        briVault.setCountry(countries);
    }

    function testOwnerIsSetCorrectly() public view {
        assertEq(briVault.owner(), owner, "Owner should be deployer");
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

    function testsetWinnerNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        briVault.setWinner(2);
    }

    function testsetWinnerBeforeEventEnd() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.warp(eventStartDate + 1);
        vm.expectRevert(abi.encodeWithSignature("eventNotEnded()"));
        briVault.setWinner(2);
        vm.stopPrank();
    }

    function testsetWinnerAfterSettingWinner () public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.warp(eventEndDate + 1);
        briVault.setWinner(2);
        vm.expectRevert(abi.encodeWithSignature("WinnerAlreadySet()"));
        briVault.setWinner(3);
        vm.stopPrank();
    }

    function test_deposit() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 10 ether);
        uint256 user1share = briVault.deposit(10 ether, user1);
        console.log("user1ShareValue:", user1share);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 10 ether);
        uint256 user2share = briVault.deposit(10 ether, user2);
        console.log("user2ShareValue:", user2share);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 10 ether);
        uint256 user3share = briVault.deposit(10 ether, user3);
        console.log("user3ShareValue:", user3share);
        vm.stopPrank();

        console.log("participationFeeAddress Balance:", mockToken.balanceOf(address(participationFeeAddress))); 
        assertEq(mockToken.balanceOf(address(participationFeeAddress)), 450000000000000000);
        assertEq(mockToken.balanceOf(address(briVault)), 30 ether - 450000000000000000);
        assertEq(briVault.balanceOf(user1), user1share);
        assertEq(briVault.balanceOf(user2), user2share);
        assertEq(briVault.balanceOf(user3), user3share);
    }

    function test_ActualStakedAsset () public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.stopPrank();

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.stopPrank();

        console.log("Actual Staked Asset:", briVault.stakedAsset(user1));
        assertEq(briVault.stakedAsset(user1), 10 ether - 150000000000000000);
    }

    function test_deposit_after_event_start() public {
        vm.warp(eventStartDate + 3);
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        vm.expectRevert(abi.encodeWithSignature("eventStarted()"));
        briVault.deposit(5 ether, user1);
        vm.stopPrank();
    }

    function test_participationFeeTransfer () public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user1share = briVault.deposit(5 ether, user1);
        console.log("user1ShareValue:", user1share);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user2Share = briVault.deposit(5 ether, user2);
        vm.stopPrank();
        console.log("Participation Fee Address Balance:", mockToken.balanceOf(address(participationFeeAddress)));
        assertEq(mockToken.balanceOf(address(participationFeeAddress)), 150000000000000000);
    }

    function test_joinEvent_noDeposit() public {
        vm.startPrank(user5);
        mockToken.approve(address(briVault), 5 ether);
        vm.expectRevert(abi.encodeWithSignature("noDeposit()"));
        briVault.joinEvent(3);
        vm.stopPrank();
    }

    function test_joinEvent_success() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user1shares = briVault.deposit(5 ether, user1);

        briVault.joinEvent(10);
        console.log("user1 shares", user1shares);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user2shares = briVault.deposit(5 ether, user2);

        briVault.joinEvent(20);
        console.log("user2 shares", user2shares);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
         uint256 user3shares = briVault.deposit(5 ether, user3);
      
        briVault.joinEvent(30);
        console.log("user3 shares", user3shares);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
         uint256 user4shares =  briVault.deposit(5 ether, user4);
    
        briVault.joinEvent(40);
        console.log("user4 shares", user4shares);
        vm.stopPrank();
        
        assertEq(briVault.balanceOf(user1), user1shares);
        assertEq(briVault.balanceOf(user2), user2shares);
        assertEq(briVault.balanceOf(user3), user3shares);
        assertEq(briVault.balanceOf(user4), user4shares);
    }

    function test_joinEventTwice () public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("alreadyJoined()"));
        briVault.joinEvent(20);
        vm.stopPrank();
    }

    function test_InvalidCountryId() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.expectRevert(abi.encodeWithSignature("invalidCountry()"));
        briVault.joinEvent(50);
        vm.stopPrank();
    }

    function test_JoinAfterEventStart() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.warp(eventStartDate + 4);
        vm.expectRevert(abi.encodeWithSignature("eventStarted()"));
        briVault.joinEvent(10);
        vm.stopPrank();
    }

    function test_userSharesToCountryMapping() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        uint256 shares = briVault.userSharesToCountry(user1, 10);
        console.log("user1 shares for country 10:", shares);
        assertEq(shares, briVault.balanceOf(user1));
        vm.stopPrank();
    }

    function test_userSharesToCountryMappingDoubleDeposit() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        uint256 sharesBefore = briVault.userSharesToCountry(user1, 10);
        console.log("user1 shares for country 10 before additional deposit:", sharesBefore);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.updateJoinEvent();
        uint256 sharesAfter = briVault.userSharesToCountry(user1, 10);
        console.log("user1 shares for country 10 after additional deposit:", sharesAfter);
    
        assertGt(sharesAfter, sharesBefore);
        vm.stopPrank();
    }

    function test_cantUpdateJoinEventWithoutJoining() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("notJoinedYet()"));
        briVault.updateJoinEvent();
        vm.stopPrank();
    }
    
    function test_UpdateDepositShareAfterJoiningEvent() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        uint256 user1shareBefore = briVault.balanceOf(user1);
        console.log("user1 share before additional deposit:", user1shareBefore);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        uint256 user1shareAfter = briVault.balanceOf(user1);
        console.log("user1 share after additional deposit:", user1shareAfter);
        assertGt(user1shareAfter, user1shareBefore);
        vm.stopPrank();
    }

    function test_cancelParticipation () public {

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.cancelParticipation();
        vm.stopPrank();

        assertEq(briVault.stakedAsset(user1), 0 ether);

        assertEq(mockToken.balanceOf(address(participationFeeAddress)), 0.075 ether);
    }

    function test_cancelParticipation_afterEventStart() public {
        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        vm.warp(eventStartDate + 4);
        vm.expectRevert(abi.encodeWithSignature("eventStarted()"));
        briVault.cancelParticipation();
        vm.stopPrank();
    }

    function test_withdraw() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.stopPrank();

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user1Shares =  briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        uint256 balanceBeforuser1 = mockToken.balanceOf(user1);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user2Shares = briVault.deposit(5 ether, user2);
        briVault.joinEvent(10);
        uint256 balanceBeforuser2 = mockToken.balanceOf(user2);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user3Shares = briVault.deposit(5 ether, user3);
        briVault.joinEvent(30);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
        uint256 user4Shares = briVault.deposit(5 ether, user4);
        briVault.joinEvent(10);
        uint256 balanceBeforuser4 = mockToken.balanceOf(user4);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.startPrank(owner);
        briVault.setWinner(10);
        console.log(briVault.finalizedVaultAsset());
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 user1Claim = briVault.getWinnerClaim();
        console.log("user1 claim:", user1Claim);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 user2Claim = briVault.getWinnerClaim();
        console.log("user2 claim:", user2Claim);
        vm.stopPrank();

        vm.startPrank(user3);
        vm.expectRevert(abi.encodeWithSignature("didNotWin()"));
        briVault.getWinnerClaim();
        vm.stopPrank();

        vm.startPrank(user4);
        uint256 user4Claim = briVault.getWinnerClaim();
        console.log("user4 claim:", user4Claim);
        vm.stopPrank();

     assertEq(mockToken.balanceOf(user1), balanceBeforuser1 + 6566666666666666666);
     assertEq(mockToken.balanceOf(user2), balanceBeforuser2 + 6566666666666666666);
     assertEq(mockToken.balanceOf(user4), balanceBeforuser4 + 6566666666666666666);
     assertEq(briVault.finalizedVaultAsset(), user1Claim + user2Claim + user4Claim);
       
    }

    function test_noDustValueLeftAfterWithdrawals() public {
        vm.startPrank(owner);
        briVault.setCountry(countries);
        vm.stopPrank();

        vm.startPrank(user1);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user1);
        briVault.joinEvent(10);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user2);
        briVault.joinEvent(10);
        vm.stopPrank();

        vm.startPrank(user3);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user3);
        briVault.joinEvent(30);
        vm.stopPrank();

        vm.startPrank(user4);
        mockToken.approve(address(briVault), 5 ether);
        briVault.deposit(5 ether, user4);
        briVault.joinEvent(10);
        vm.stopPrank();

        vm.warp(eventEndDate + 1);
        vm.startPrank(owner);
        briVault.setWinner(10);
        vm.stopPrank();

        vm.startPrank(user1);
        briVault.getWinnerClaim();
        vm.stopPrank();

        vm.startPrank(user2);
        briVault.getWinnerClaim();
        vm.stopPrank();

        vm.startPrank(user4);
        briVault.getWinnerClaim();
        vm.stopPrank();

        console.log("Finalized Vault Asset:", briVault.finalizedVaultAsset());
        assertEq(briVault.finalizedVaultAsset(), 0);
    }
    
}