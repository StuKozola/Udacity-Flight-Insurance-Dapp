// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    IFlightSuretyData private data;         // data contract interface

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    // funding limits
    uint256 private constant MIN_AIRLINE_FUNDING = 10 ether;
    uint256 private constant MAX_INSURANCE = 1 ether;
    uint256 private constant MIN_INSURNCE = 1 wei;

    // multipart consensus
    uint256 private constant MIN_AIRLINES = 4;
    uint constant MIN_PCT_VOTING = 50;          // 50% of votes required

 
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
         // Modify to call data contract's status
        require(data.isOperational(), "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor( address contractID ) {
        contractOwner = msg.sender;
        data = IFlightSuretyData(contractID);
        data.registerAirline(contractOwner, "Udacity Airlines");
        data.setAirlineParticipant(contractOwner);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function getPassengerCredit(address passengerID) view external requireIsOperational returns(uint256)
    {
        return data.getPassengerCredit(passengerID);
    }
    
    function isAirlineFunded( address airlineID ) view external requireIsOperational returns(bool)
    {
        return data.isAirlineFunded(airlineID);
    }

    function isAirlineRegistered( address airlineID ) view external requireIsOperational returns(bool)
    {
        return data.isAirlineRegistered(airlineID);
    }

    function isOperational() public view returns(bool) 
    {
        return data.isOperational();
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline( address airlineID, string memory name ) external 
    requireIsOperational returns(bool success, uint256 votes)
    {
        // requirments
        require(data.isAirlineParticipating(msg.sender), "Sender is not a participating airline");
        require(data.isAirlineRegistered(airlineID), "Airline is arleady registered but not voted for yet");
        require(data.isAirlineCandidate(msg.sender), "Sender is not funded, airline can NOT be registered");

        // test for the case where there are less the 5 registered airlines
        if(data.getNumberOfRegisteredAirlines() < MIN_AIRLINES) {
            require(data.isAirlineParticipating(airlineID), "Only participating airlines can register other airlines for now");
        }

        // register airline
        data.registerAirline(airlineID, name);

        //if airline is registered by participating airline, no voting needed
        if (data.isAirlineParticipating(msg.sender)) {
            votes = voteForAirline(airlineID, msg.sender);
        }
        return (true, votes);
    }

    function voteForAirline(address airlineID, address approverID) 
    internal returns(uint256 votes)
    {
        uint256 votesNeeded;
        uint256 numberOfParticipants = data.getNumberOfRegisteredAirlines();
        uint256 votesFor;

        // add the current approvers vote
        data.voteForAirline(airlineID, approverID);
        votesFor = data.getAirlineVotes(airlineID);

        // test for case where airlines are to low for consensus voting
        if (numberOfParticipants < MIN_AIRLINES) {
            votesNeeded = 1;
        } else {
            // needs consesus voting
            votesNeeded = numberOfParticipants * MIN_PCT_VOTING / 100;
        }

        if (votesFor >= votesNeeded) {
            data.setAirlineParticipant(airlineID);
        }
        
        return votesFor;
    }

    function fundAirline(address airlineID) requireIsOperational payable external
    {    
        //require statements
        require(data.isAirlineRegistered(airlineID), "Airline to be funded is NOT registered");
        require(data.isAirlineFunded(airlineID) == false, "Airline is already funded");
        require(msg.value >= MIN_AIRLINE_FUNDING, "Airline funding amoung must be 10 Ether or more");
      //  data.fundAirline.value(msg.value)(airlineID, msg.value);
    }

    // Register a future flight for insuring.  
    function registerFlight() external pure
    {
    }
    
   // Called after oracle has updated flight status
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal
    {
        if( statusCode == STATUS_CODE_LATE_AIRLINE) {
            bytes32 flightKey = getFlightKey(airline, flight, timestamp);
            data.creditInsurees(flightKey);
        }
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp                            
    ) external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key].requester =  msg.sender;
        oracleResponses[key].isOpen = true;
        emit OracleRequest(index, airline, flight, timestamp);
    }

    function payCreditDue(address payable passengerID) external {
        require(passengerID != address(0), "Must provide a valide address");
        data.pay(passengerID);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string memory flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

//interface function to FlightSuretyData
interface IFlightSuretyData {
    function creditInsurees(bytes32 flightKey) external;
    function fundAirline(address airlineID, uint256 amount) external payable;
    function getAirlineVotes(address airlineID) external view returns(uint256);
    function getPassengerCredit(address passengerID) external view returns(uint256);
    function getNumberOfRegisteredAirlines() external view returns(uint256);
    function isAirlineFunded(address airlineID) external view returns(bool);
    function isAirlineCandidate(address airlineID) external view returns(bool);
    function isAirlineParticipating(address airlineID) external view returns(bool);
    function isAirlineRegistered(address airlineID) external view returns(bool);
    function isOperational() external view returns(bool);
    function pay(address passenger) external payable;
    function registerAirline(address airlineID, string memory name) external;
    function setAirlineParticipant( address airlineID ) external;
    function voteForAirline(address airlineID, address approverID) external;
}
