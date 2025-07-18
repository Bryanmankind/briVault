// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract BriVault is ERC4626, Ownable {

    using SafeERC20 for IERC20;
    
    uint256 public participationFeeBsp;

    uint256 constant PRECISION = 1e18;
    /**
    @dev participationFee address
     */
    address private participationFeeAddress;
    uint256 public eventStartDate;
    uint256 public eventEndDate;
    uint256 public  stakedAmount;
    uint256 public totalAssetsShares;
    uint256 public winner;
    uint256 public finalizedVaultAsset;
    uint256 public totalWinnerShares;
    bool public _setWinner;

    // minimum amount to join in.
    uint256 public  minimumAmount; 

    // number of participants 
    uint256 public numberOfParticipants;

    // Array of teams 
    uint256[48] public teams;
    address[] public usersAddress;

    // Error Logs
    error eventStarted();
    error lowFeeAndAmount();
    error invalidCountry();
    error eventNotEnded();
    error didNotWin();
    error notRegistered();
    error winnerNotSet();
    error noDeposit();
    error eventNotStarted();

    event deposited (address indexed _depositor, uint256 _value);
    event CountriesSet(uint256[48] country);
    event joinedEvent(address user, uint256 _countryId);
    event Withdraw (address user, uint256 _amount);  

    mapping (address => uint256) public depositAsset;
    mapping(uint256 => uint256) public countryToTeamIndex;
    mapping (address => uint256) public userToCountry;
    mapping (address => mapping (uint256 => uint256)) public userSharesToCountry;
    

    constructor (IERC20 _asset, uint256 _participationFeeBsp, uint256 _eventStartDate, address _participationFeeAddress, uint256 _minimumAmount, uint256 _eventEndDate) ERC4626 (_asset) ERC20("BriTechLabs", "BTT") Ownable(msg.sender) {
         participationFeeBsp = _participationFeeBsp;
         eventStartDate = _eventStartDate;
         eventEndDate = _eventEndDate;
         participationFeeAddress = _participationFeeAddress;
         minimumAmount= _minimumAmount;
         _setWinner = false;
         totalAssetsShares = 1000000;                     // total asset manage by the vault
    }

    modifier winnerSet () {
        if (_setWinner != true) {
          revert winnerNotSet();
        }
        _;
    }

    function setCountry(uint256[48] memory countries) public onlyOwner {
        for (uint256 i = 0; i < countries.length; ++i) {
            countryToTeamIndex[i + 1] = countries[i];
            teams[i] = countryToTeamIndex[i + 1];
        }
        emit CountriesSet(countries);
    }

    function setWinner(uint256 countryId) public onlyOwner returns (bool) {
        if (block.timestamp <= eventEndDate) {
            revert eventNotEnded();
        }

        if (countryToTeamIndex[countryId] != 0) {
            revert invalidCountry();
        }

        winner = countryToTeamIndex[countryId];

        _getWinnerShares();

        _setWinner = true;

        return _setWinner;
    }

    function setFinallizedVaultBalance () public onlyOwner returns (uint256) {
        if (block.timestamp <= eventStartDate) {
            revert eventNotStarted();
        }

        return finalizedVaultAsset = address(this).balance;
    }

    function getWinner () public view returns (uint256) {
        return winner;
    }

    function getTeamIndexForCountry(uint256 countryId) external view returns (uint256) {
        return countryToTeamIndex[countryId];
    }

    function _getWinnerShares () internal returns (uint256) {

        for (uint256 i = 0; i < usersAddress.length; ++i){
            address user = usersAddress[i];
           totalWinnerShares += userSharesToCountry[user][winner];
        }
        return totalWinnerShares;
    }

    /**
    @dev allows users to deposit for the event.
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        require(receiver != address(0));

        if (block.timestamp >= eventStartDate) {
            revert eventStarted();
        }

        if (minimumAmount + participationFeeBsp < assets) {
            revert lowFeeAndAmount();
        }

        uint256 stakeAsset = assets - participationFeeBsp;

        depositAsset[receiver] = stakeAsset;

        IERC20(asset()).transferFrom(msg.sender, participationFeeAddress, participationFeeBsp);

        IERC20(asset()).transferFrom(msg.sender, address(this), stakeAsset);

        emit deposited (receiver, stakeAsset);

        return 0;
    }

    function _convertToShares (uint256 assets) internal view returns (uint256 shares) {
        uint256 balanceOfVault = address(this).balance;
        shares = (assets * totalAssetsShares * PRECISION) / balanceOfVault;
        shares = shares / PRECISION;
    }

    /**
    @dev allows users to join the event 
    */
    function joinEvent (uint256 countryId) public returns (uint256 participantShares) {
        if (depositAsset[msg.sender] == 0) {
            revert noDeposit();
        }

        bool valid = false;

        for (uint256 i = 0; i <= 48; ++i) {
            if (countryToTeamIndex[i] == countryId) {
                valid = true;
                break;
            }
            if (!valid){
                revert invalidCountry(); 
            }
        }
        require(block.timestamp <= eventStartDate, eventStarted());

        uint256 stakeAsset = depositAsset[msg.sender];

        participantShares = _convertToShares(stakeAsset);

        stakedAmount += depositAsset[msg.sender];

        userToCountry[msg.sender] = countryId;

        userSharesToCountry[msg.sender][countryId] = participantShares;

        depositAsset[msg.sender] = 0;

        usersAddress.push(msg.sender);

        numberOfParticipants++;

        _mint(msg.sender, participantShares);

        emit joinedEvent (msg.sender, countryId);
    }

    /**
    @dev cancell participation 
     */
    function cancellParticipation () public  {
        if (block.timestamp >= eventStartDate){
           revert eventStarted();
        }

        uint256 refundAmount = depositAsset[msg.sender];

        depositAsset[msg.sender] = 0;

        transferFrom(address(this), msg.sender, refundAmount);
    }

    /**
    @dev allows users to get back there wins
    */
    function withdraw (uint256 shares) external winnerSet {
        if (block.timestamp <= eventEndDate) {
            revert eventNotEnded();
        }

        if (userToCountry[msg.sender] != winner) {
            revert didNotWin();
        }

        uint256 assetToWithdraw = (shares * finalizedVaultAsset * 1e18) / totalWinnerShares;
        uint256 assetToWithdraw = assetToWithdraw * 1e18

        _burn(msg.sender, shares);

       transferFrom(address(this), msg.sender, assetToWithdraw);

        emit Withdraw (msg.sender, assetToWithdraw);
    }

}
