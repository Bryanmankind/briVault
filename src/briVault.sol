// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract BriVault is ERC4626, Ownable {

    uint256 public participationFeeBsp;
    /**
    @dev participationFee address
     */
    address private participationFeeAddress;
    uint256 public eventStartDate;
    uint256 public eventEndDate;
    uint256 public  stakedAmount;
    uint256 public totalAssetsShares;
    uint256 public winner;
    bool public _setWinner;

    // minimum amount to join in.
    uint256 public  minimumAmount; 

    // number of participants 
    uint256 public numberOfParticipants;

    // Array of teams 
    uint256[48] public teams;

    // Error Logs
    error eventStarted();
    error lowFeeAndAmount();
    error invalidCountry();
    error eventNotEnded();
    error didNotWin();
    error notRegistered();
    error winnerNotSet();


    event deposited (address indexed _depositor, uint256 _value);
    event CountriesSet(uint256[48] country);
    event joinedEvent(address user, uint256 _countryId);
    event Withdraw (address user, uint256 _amount);  

    mapping (address => uint256) public depositAsset;
    mapping(uint256 => uint256) public countryToTeamIndex;
    mapping (address => uint256) public userToCountry;
    

    constructor (IERC20 _asset, uint256 _participationFeeBsp, uint256 _eventStartDate, address _participationFeeAddress, uint256 _minimumAmount, uint256 _eventEndDate) ERC4626 (_asset) ERC20("BriTechLabs", "BTT") Ownable(msg.sender) {
         participationFeeBsp = _participationFeeBsp;
         eventStartDate = _eventStartDate;
         eventEndDate = _eventEndDate;
         participationFeeAddress = _participationFeeAddress;
         minimumAmount= _minimumAmount;
         _setWinner = false;
         totalAssetsShares = 1000000;                     // total asset manage by the vault
    }

    /**
    @dev receive sent eth
     */
    
    receive() external payable {}

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

    function setWinner (uint256 countryId) public onlyOwner returns (bool) { // get winner in real time offchain
        require(block.timestamp >= eventEndDate, eventNotEnded());
        
        for (uint256 i = 0; i <= 48; ++i) {
            if (countryToTeamIndex[countryId] == countryId) {
                valid = true;
                break;
            }
            require(valid, invalidCountry()); 
        }

        winner = countryToTeamIndex[countryId];

        _setWinner = true;

        return (true)
    }

    function getWinner () public view returns (uint256) {
        return winner;
    }

    function getTeamIndexForCountry(uint256 countryId) external view returns (uint256) {
        return countryToTeamIndex[countryId];
    }

    function getVaultBalance () public view returns(uint256) {
        address(this).balance;
    }

    /**
    @dev allows users to deposit for the event.
     */
    function deposit(uint256 assets, address receiver) public override {
        require(receiver != address(0));
        require(block.timestamp <= eventStartDate, eventStarted());
        require(minimumAmount + participationFeeBsp <= assets, lowFeeAndAmount());

        uint256 stakeAsset = assets - participationFeeBsp;

        depositAsset[receiver] = stakeAsset;

        _transfer(msg.sender, participationFeeAddress, participationFeeBsp);

        _transfer(msg.sender, address(this), stakeAsset);

        emit deposited (receiver, stakeAsset);
    }

    function _convertToShares (uint256 assets) view internal returns (uint256 shares) {
        balanceOfVault = getVaultBalance();
        shares = (assets * totalAssetsShares) / balanceOfVault;
    }

    /**
    @dev allows users to join the event 
    */
    function joinEvent (uint256 countryId) public returns (uint256 participantShares) {
        bool valid = false;

        for (uint256 i = 0; i <= 48; ++i) {
            if (countryToTeamIndex[countryId] == countryId) {
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

        userToCountry[msg.sender] = [countryId];

        depositAsset[msg.sender] = 0;

        numberOfParticipants++;

        _mint(msg.sender, participantShares);

        emit joinedEvent (msg.sender, countryId);
    }

    /**
    @dev cancell participation 
     */
    function cancellParticipation () public  {
        if (block.timestamp >= eventStartDate){
            eventStarted()
        }

        refundAmount = depositAsset[msg.sender];

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

        uint256 vaultBalance = getVaultBalance();

        uint256 assetToWithdraw = (shares * vaultBalance) / totalAssetsShares;

        _burn(msg.sender, shares);

        transferFrom(address(this), msg.sender, assetToWithdraw);

        emit Withdraw (msg.sender, assetToWithdraw);
    }

    function sweepEth () public onlyOwner {
        uint256 balance = address(this).balance;
       (bool success,) = payable(msg.sender).call{value: balance}("");
       require(success);
    }

}

