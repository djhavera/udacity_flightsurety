pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedCaller;
    address[] enabledAirlines = new address[](0);

    struct Airline {
        bool isRegistered;
        //bool isFunded;
        uint256 funds;
    }
    mapping(address => Airline) private airlines;

    struct FlightInsurance {
        bool isInsured;
        bool isCredited;
        uint256 amount;
    }
    // the contract holds balance of insurance
    uint256 private balance = 0 ether;
    // registration fee
    uint256 constant registration = 10 ether;
    mapping(address => uint256) funds;
    mapping(address => uint256) private insuredBalances;
    mapping(bytes32 => FlightInsurance) private flightInsurances;
    mapping(bytes32 => address[]) private insuredsMap;

    address[] private registeredAirlines;
    // the contract holds balance of insurance



    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address _firstAirline
                                )
                                public
    {
        contractOwner = msg.sender;

        // Create first Airline - but without funding
        airlines[_firstAirline] =  Airline({isRegistered: true, funds : 0});
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    modifier requireIsCallerAuthorized()
    {
        require(authorizedCaller[msg.sender] == 1 || msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

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


    modifier requireFlightNotInsured(address _originSender, address _airline, string _flightNumber, uint256 _timestamp)
    {
        require(!isFlightInsured(_originSender, _airline, _flightNumber, _timestamp), "Flight already insured");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function authorizeCaller(address contractAddress) external //requireContractOwner
    {
        authorizedCaller[contractAddress] = 1;
    }

    function deauthorizeCaller(address contractAddress) external //requireContractOwner
    {
        delete authorizedCaller[contractAddress];
    }

    function isAuthorizedCaller(address contractAddress)
                            public
                            view
                            requireContractOwner
                            returns(bool)
    {
        return authorizedCaller[contractAddress] == 1;
    }

    function isCallerAirlineRegistered(address _originSender)
                            public
                            view
                            returns (bool)
    {
        return airlines[_originSender].isRegistered;
    }

    function isCallerAirlineFunded(address _originSender)
                            public
                            view
                            returns (bool success)
    {
        return airlines[_originSender].funds >= registration;
    }


    function isFlightInsured(address _originSender, address _airline, string _flightNumber, uint256 _timestamp)
                            public
                            view
                            returns (bool)
    {
        FlightInsurance storage insurance = flightInsurances[getInsuranceKey(_originSender, _airline, _flightNumber, _timestamp)];
        return insurance.isInsured;
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
                                bool _mode
                            )
                            external
                            //requireContractOwner
    {
        operational = _mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function getBalance
                            (
                            )
                            public
                            view
                            requireIsOperational
                            //requireContractOwner
                            returns (uint256)
    {
        return address(this).balance;
    }

    function isAirline
                            (
                                address _airline
                            )
                            external
                            view
                            requireIsOperational
                            returns (bool)

    {
        return airlines[_airline].isRegistered;
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
                            ( 
                                address _address   
                            )
                            public
                            //requireIsOperational
    {  
        airlines[_address] = Airline ({
                                        isRegistered: true,
                                        funds: 0

                                    });
        registeredAirlines.push(_address);
    }

    function fundAirline 
                            ( address _airline, 
                            uint256 _fund ) 
                            public 
                            payable 
                            requireIsOperational 
    { 
        airlines[_airline].funds = airlines[_airline].funds.add(_fund); 
        balance = balance.add(_fund); 
    }
    function fetchinsuredAmount
                            (
                                address originSender,
                                address airline,
                                string flightNumber,
                                uint256 timestamp
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            view
                            returns (uint256)
    {
        return flightInsurances[getInsuranceKey(originSender, airline, flightNumber, timestamp)].amount;
    }

    function insuredBalance
                            (
                                address originSender
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            view
                            returns (uint256)
    {
        return insuredBalances[originSender];
    }

   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
                            (
                                address originSender,
                                address airline,
                                string flightNumber,
                                uint256 timestamp,
                                uint256 amount
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            requireFlightNotInsured(originSender, airline, flightNumber, timestamp)
    {
        FlightInsurance storage insurance = flightInsurances[getInsuranceKey(originSender, airline, flightNumber, timestamp)];
        insurance.isInsured = true;
        insurance.amount = amount;

        // Add insured to list of all insureds (if not exists)
        appendinsured(originSender, airline, flightNumber, timestamp);
    }

    function appendinsured
                            (
                                address originSender,
                                address airline,
                                string flightNumber,
                                uint256 timestamp
                            )
                            internal
                            requireIsOperational
    {
        address [] storage insureds = insuredsMap[getInsuranceKey(0x0, airline, flightNumber, timestamp)];
        bool duplicate = false;
        for(uint256 i = 0; i < insureds.length; i++) {
            if(insureds[i] == originSender) {
                duplicate = true;
                break;
            }
        }

        if(!duplicate) {
            insureds.push(originSender);
        }
    }

    /**
     *  @dev Credits payouts to insureds
    */
    function creditinsureds
                                (
                                    address airline,
                                    string flightNumber,
                                    uint256 timestamp
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
    {
        address [] storage insureds = insuredsMap[getInsuranceKey(0x0, airline, flightNumber, timestamp)];

        for(uint i = 0; i < insureds.length; i++) {
            FlightInsurance storage insurance = flightInsurances[getInsuranceKey(insureds[i], airline, flightNumber, timestamp)];

            // if instead of require so that a single mistake does not endanger the payouts of other policyholders
            if(insurance.isInsured && !insurance.isCredited) {
                insurance.isCredited = true;
                insuredBalances[insureds[i]] = insuredBalances[insureds[i]].add(insurance.amount.mul(15).div(10));
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insured
     *
    */
    function pay
                            (
                                address _originSender
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        require(address(this).balance > insuredBalances[_originSender], "Caller is out of Money");

        uint256 prev = insuredBalances[_originSender];
        insuredBalances[_originSender] = 0;
        _originSender.transfer(prev);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */

    function getInsuranceKey
                        (
                            address _insured,
                            address _airline,
                            string memory _flight,
                            uint256 _timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(_insured, _airline, _flight, _timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */

    function fund
                            (
                            )
                            public
                            payable
                           
    {
        balance = balance.add(msg.value);   
    }

    function()
                            external
                            payable
    {
        fund();
    }


}