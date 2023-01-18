pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;    // Account used to deploy contract
    bool private operational = true;  // Blocks all state changes throughout the contract if false

    mapping(address => bool) private authorizedCallerList;      // list of authorized callers
    mapping(address => Airline) private registeredAirlineList; // list of registered airlines

    // Airline data contains the airline ID, name, funded state, and voting count
    struct Airline {
        address airlineID;
        string name;
        bool isFunded;
    }

    uint256 numberOfRegisteredAirlines = 0;     // number of registered airlines
    uint256 totalFunds = 0;                     // total amount of funding available

    // Passenger data
    struct Passenger {

    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
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
        require(operational, "Contract is currently not operational");
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
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get registered airline count
    *
    * @return A bool that is the current operating status
    */      
    function getNumberOfRegisteredAirlines()
                            external 
                            view 
                            returns(uint256) 
    {
        return numberOfRegisteredAirlines;
    }

    function isAirlineRegistered
                                (
                                    address airlineID
                                )
                                external
                                view
                                returns(bool)                           
    {
        return registeredAirlineList[airlineID].airlineID != address(0);
    }
    
    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

   
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
    * @dev Sets authorized caller
    *
    * Set the address of the contracts allowed to call data
    */    
    function authorizeCaller
                            (
                                address contractID
                            ) 
                            public
    {
        authorizedCallerList[contractID] = true;
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address airlineID,
                                string name
                            )
                            public
                            requireIsOperational
    {
        registeredAirlineList[airlineID] = Airline({
            airlineID: airlineID,
            name: name,
            isFunded: false
        });

        numberOfRegisteredAirlines = numberOfRegisteredAirlines.add(1);
    }

    /**
    * @dev Fund the airline
    *
    */ 
    function fundAirline
                        (
                            address airlineID,
                            uint256 amount
                        )
                        external
                        payable
                        requireIsOperational
    {
        registeredAirlineList[airlineID].isFunded = true;
        totalFunds = totalFunds.add(amount);

    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

