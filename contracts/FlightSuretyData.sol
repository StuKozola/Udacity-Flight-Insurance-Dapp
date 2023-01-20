// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract FlightSuretyData {

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;    // Account used to deploy contract
    bool private operational = true;  // Blocks all state changes throughout the contract if false
    
    uint256 numberOfRegisteredAirlines = 0;     // number of registered airlines
    uint256 totalFunds = 0;                     // total amount of funding available
    
    address[] public passengerList;             // list of insured passenger addresses

    mapping(address => bool) private authorizedCallerList;      // list of authorized callers
    mapping(address => Airline) private registeredAirlineList;  // list of registered airlines
    mapping(address => AirlineVotes) private voterLog;          // tally of votes and voters
    mapping(address => Passenger) private passengers;           // list of passengers and insured flights

    uint256 private constant PAYOUT_MULTIPLE = 150;  // payout multiple in percent          


    // Airline data 
    enum AirlineState {
        UNKNOWN,        // default state
        PENDING,        // waiting for voting consensus
        REGISTERED,     // can register, but is not funded
        PARTICIPANT     // must be funded to participate
    }

    struct Airline {
        address airlineID;
        string name;
        AirlineState status;
    }

    struct AirlineVotes {
        uint256 votes;
        mapping(address => bool) voters;
    }

    // Passenger data
    struct Passenger {
        address passengerID;
        mapping(bytes32 => uint256) flightsInsured;
        uint256 payout;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor()
    {
        contractOwner = msg.sender;
        passengerList = new address[](0);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently NOT operational");
        _;
    }

    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is NOT contract owner");
        _;
    }

    modifier requireAuthorizedCaller()
    {
        require(authorizeCaller(msg.sender), "Caller is NOT authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/
    
    // amount of any payout remaining for passenger
    function getPassengerCredit(address passengerID) external view returns(uint256) {
        return passengers[passengerID].payout;
    }

    // number of airlines registered
    function getNumberOfRegisteredAirlines() external view  returns(uint256) 
    {
        return numberOfRegisteredAirlines;
    }

    // get votes for an airline
    function getAirlineVotes(address airlineID) external view returns(uint256)
    {
        return voterLog[airlineID].votes;
    }

    function isAirlineFunded( address airlineID ) external view returns(bool)                           
    {
        return registeredAirlineList[airlineID].status == AirlineState.PARTICIPANT;
    }
    
    function isAirlineParticipant( address airlineID ) external view returns(bool)                           
    {
        return registeredAirlineList[airlineID].status == AirlineState.PARTICIPANT;
    }

    function isAirlineRegistered( address airlineID ) external view returns(bool)                           
    {
        return registeredAirlineList[airlineID].status == AirlineState.REGISTERED;
    }
     
    function isOperational() public view returns(bool) 
    {
        return operational;
    }

    function setAirlinePending( address airlineID ) requireAuthorizedCaller external
    {
        registeredAirlineList[airlineID].status = AirlineState.PENDING;
    }

    function setAirlineParticipant( address airlineID ) requireAuthorizedCaller external
    {
        registeredAirlineList[airlineID].status = AirlineState.PARTICIPANT;
    }

    function setAirlineRegistered( address airlineID ) requireAuthorizedCaller external
    {
        registeredAirlineList[airlineID].status = AirlineState.REGISTERED;
    }
  
    function setOperatingStatus( bool mode ) external requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    // Set the address of the contracts allowed to call data    
    function authorizeCaller( address contractID ) requireIsOperational  public returns(bool)
    {
        authorizedCallerList[contractID] = true;
        return authorizedCallerList[contractID];
    }

    // register airline, Can only be called from FlightSuretyApp contract
    function registerAirline( address airlineID, string memory name ) 
    requireIsOperational requireAuthorizedCaller external
    {
        registeredAirlineList[airlineID].airlineID =  airlineID;
        registeredAirlineList[airlineID].name =  name;
        registeredAirlineList[airlineID].status =  AirlineState.PENDING;
        numberOfRegisteredAirlines = numberOfRegisteredAirlines + 1;
    }

    // Fund the airline
    function fundAirline( address airlineID, uint256 amount ) requireIsOperational external payable
    {
        registeredAirlineList[airlineID].status = AirlineState.PARTICIPANT;
        totalFunds = totalFunds + amount;

    }

    // voting for an airline
    function voteForAirline(address airlineID, address approverID) 
    requireIsOperational
    requireAuthorizedCaller
    external
    {
        voterLog[airlineID].votes++;
        voterLog[airlineID].voters[approverID] = true;
    }

    // Buy insurance for a flight
    function buy(address passengerID, bytes32 flightKey, uint256 amount) requireIsOperational external payable
    {
        // check if this passenger exits
        if (passengers[passengerID].passengerID != address(0)) {
            // are they already insured for this flight?
            require(passengers[passengerID].flightsInsured[flightKey] == 0, "Can NOT add insurance to existing insured flight");
        } else {
            // new passenger so add them
            passengers[passengerID].passengerID = passengerID;
            passengers[passengerID].payout = 0;
            passengerList.push(passengerID);
        }
        passengers[passengerID].flightsInsured[flightKey] = amount;
        totalFunds = totalFunds + amount;
    }

    // Credits payouts to insurees
    function creditInsurees(bytes32 flightKey) requireIsOperational external
    {
        // for this flight
        for (uint256 i = 0; i < passengerList.length; i++) {
            // find all insured passengers on flight
            if (passengers[passengerList[i]].flightsInsured[flightKey] != 0) {
                // refund PAYOUT_MULTIPLE times the price paid
                uint256 pricePaid = passengers[passengerList[i]].flightsInsured[flightKey];
                passengers[passengerList[i]].payout = passengers[passengerList[i]].payout + PAYOUT_MULTIPLE/100 * pricePaid;
            }
        }
    }
    

    // Transfers eligible payout funds to insuree
    function pay(address payable passengerID) requireIsOperational requireAuthorizedCaller external payable
    {
        // requirements, make sure we pay the passenger only
        require(passengers[passengerID].passengerID != address(0), "Passenger is note insured");
        require(passengers[passengerID].payout> 0, "Passenger does not have a credit balance to payout");
        require(address(this).balance >= passengers[passengerID].payout, "This contract does not have sufficeint funds to pay");
        uint256 payout = passengers[passengerID].payout;
        passengers[passengerID].payout = 0;
        passengerID.transfer(payout);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund()  requireIsOperational requireAuthorizedCaller public payable
    {
    }

    function getFlightKey (
        address airline,
        string memory flight,
        uint256 timestamp
    ) pure internal returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() external payable {
        fund();
    }

    receive() external payable {
        fund();
    }

}

