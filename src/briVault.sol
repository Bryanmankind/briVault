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
    uint256 public totalAssets;

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


    event deposited (address indexed _depositor, uint256 _value);
    event CountriesSet(uint256[48] country);
    event joinedEvent(address user, uint256 _countryId);

    mapping (address => uint256) public depositAsset;
    mapping(uint256 => uint256) public countryToTeamIndex;

    constructor (IERC20 _asset, uint256 _participationFeeBsp, uint256 _eventStartDate, address _participationAddress, uint256 _minimumAmount) ERC4626 (_asset) ERC20("BriTechLabs", "BTT") Ownable(msg.sender) {
         participationFeeBsp = _participationFeeBsp;
         eventStartDate = _eventStartDate;
         participationFeeAddress = _participationFeeAddress;
         minimumAmount= _minimumAmount;
         totalAssets = 1000000;                     // total asset manage by the vault
    }

    /**
    @dev receive sent eth
     */
    
    receive() external payable {}

    function setCountry(uint256[48] memory countries) public onlyOwner {
        for (uint256 i = 0; i < countries.length; ++i) {
            countryToTeamIndex[i + 1] = countries[i];
            teams[i] = countryToTeamIndex[i + 1];
        }
        emit CountriesSet(countries);
    }

    function getTeamIndexForCountry(uint256 countryId) external view returns (uint256) {
        return countryToTeamIndex[countryId];
    }

    /**
    @dev allows users to deposit for the evevt.
     */
    function deposit() public payable override {
        require(block.timestamp <= eventStartDate, eventStarted());
        require(minimumAmount + participationFeeBsp <= msg.sender, lowFeeAndAmount());

        uint256 stakeAsset = msg.value - participationFeeBsp;

        depositAsset[msg.sender] = stakeAsset;

        _transfer(msg.sender, participationAddress, participationFeeBsp);

        _transfer(msg.sender, address(this), stakeAsset);

        emit deposited (msg.sender, stakeAsset);
    }

    /**
    @dev allows users to join the event 
    */
    function joinEvent (uint256 countryId) public returns (uint256 shares) {
        bool valid = false;

        for (uint256 i = 0; i <= 48; ++i) {
            if (countryToTeamIndex[countryId] == countryId) {
                valid = true;
                break;
            }
            require(valid, invalidCountry());
        }
        require(block.timestamp <= eventStartDate, eventStarted());

        uint256 stakeAsset = depositAsset[msg.sender];

        uint256 participantShares = _convertToShares(stakeAsset);

        stakedAmount += depositAsset[msg.sender];

        depositAsset[msg.sender] = 0;
        numberOfParticipants++;

        _mintShares (msg.sender, particioantShares);

        emit joinedEvent (msg.sender, participantShares, countryId);
        
        return (uint256 participantShares);
    }

    function _convertToShares (uint256 assets) view internal returns (uint256 shares) {

    }

    function _mintShares (msg.sender, particioantShares) internal {

        mint(address(0), particioantShares);
    }

    /**
    @dev cancell participation 
     */
    function cancellParticipation () {}

    /**
    @dev allows users to get back there wins
    */
    function redeem(shares, receiver, owner){}

    function vaultNAV () {}

}

