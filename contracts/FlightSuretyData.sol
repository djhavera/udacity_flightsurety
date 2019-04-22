pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Account used to deploy contract
    address private contractOwner; 

    // Blocks all state changes throughout the contract if false
    bool private operational = true;                                    

    // maps authorizedpassenger variable to address of integer
    mapping(address => uint256) private authorizedpassenger;                

    //Captures the attributes of the airline
    struct AirlineStruct {
        bool isRegistered;
        uint256 funds;
    }

    // maps airline variable to struct
    mapping(address => AirlineStruct) private airlines;
    //array
    address[] private registeredAirlines;

    //Captures the attributes of passenger
    struct PassengerStruct {
        bool isInsured;     
        bool[] isPaid;
        uint256[] insurance;
        string[] flights;
    }

    mapping(address => PassengerStruct) private passengersMapping;
    mapping(string => address[]) flightPassengers;


    // the contract holds balance of insurance
    uint256 private balance = 0 ether;
    // registration fee
    uint256 constant registration = 10 ether;

    // passenger[x].funds
    mapping(address => uint256) private insurancePayment;

   // consensus array
    address[] public multiCalls = new address[](0);
    //Flight mapping Amount
    mapping(string => uint256) private flightInsuranceAmount;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    //https://ethereum.stackexchange.com/questions/56443/what-does-mean-before-a-variable-name
    constructor
                                (
                                    address _airline
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        // Create first Airline
        airlines[_airline] =  AirlineStruct({isRegistered: true, funds: 0});
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

    modifier requireIspassengerAuthorized()
    {
        require(authorizedpassenger[msg.sender] == 1 ||msg.sender == contractOwner, "passenger is not Authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

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

    function authorizePassengerFunction(address contractAddress) external requireContractOwner
    {
        authorizedpassenger[contractAddress] = 1;
    }

    function deauthorizepassengerFunction(address contractAddress) external requireContractOwner
    {
        delete authorizedpassenger[contractAddress];
    }
    function isAirlineRegisteredFunction
                            (
                                address _address
                            )
                            external
                            view
                            returns(bool)
    {
        return airlines[_address].isRegistered;
    }

    function isAirlineFunded
                            (
                                address _airline
                            ) 
                            external 
                            view 
                            requireIsOperational 
                            returns (bool) 
    {
        return airlines[_airline].funds >= registration;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirlineFunction
                            (   
                                address _address 
                            )
                            external
                            requireIsOperational
                    
    {
        airlines[_address] = AirlineStruct ({
                                        isRegistered: true,
                                        funds: 0
                                    });
        registeredAirlines.push(_address);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyFunction
                            (   
                            address _passenger,
                            uint256 _insurancePrice,
                            string _flight
                            )
                            external
                            payable
                            requireIsOperational
                            requireIspassengerAuthorized
    {
        string[] memory flights = new string[](3);
        bool[] memory paid = new bool[](3);
        uint256[] memory insurance = new uint[](3);
        uint index;

        if(passengersMapping[_passenger].isInsured == true){
            index = fetchFlightIndexFunction(_passenger, _flight) ;
            require(index == 0, "Passenger is insured.");

        }else {
            paid[0] = false;
            insurance[0] = _insurancePrice;
            flights[0] = _flight;
            passengersMapping[_passenger] = PassengerStruct({isInsured: true, isPaid: paid, insurance: insurance, flights: flights});
        }

        // pay for the insurance amount
        balance = balance.add(_insurancePrice);
        flightPassengers[_flight].push(_passenger);
        flightInsuranceAmount[_flight] = flightInsuranceAmount[_flight].add(_insurancePrice);
    }

    /**
     *  @dev Credits payouts to insurees
    */

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function payFunction
                            (
                                address _originSender
                            )
                            public
                            payable
                            requireIsOperational
                            requireIspassengerAuthorized
    {
        require(address(this).balance > insurancePayment[_originSender], "Insufficient Funds");

        uint256 deposit = insurancePayment[_originSender];
        insurancePayment[_originSender] = 0;
        balance = balance.sub(deposit);
        _originSender.transfer(deposit);
    }

    function setInsuredFunction
                        (
                            string _flight, 
                            address _passenger,
                            uint _amount
                        ) 
                        external 
                        requireIsOperational
                        requireIspassengerAuthorized
    {

        uint index = fetchFlightIndexFunction(_passenger, _flight) - 1;
        passengersMapping[_passenger].isPaid[index] = true;
        insurancePayment[_passenger] = insurancePayment[_passenger].add(_amount);
    }

    function getInsuredFunction
                        (
                            string _flight
                        ) 
                        external 
                        view 
                        requireIsOperational 
                        returns(address[] passengers)
    {
        return flightPassengers[_flight];
    }

    function getRegisteredAirlinesNumberFunction() public view requireIsOperational returns (uint num){
        return registeredAirlines.length;
    }

    function isAirlineRegistered(address _airline) public view requireIsOperational returns (bool success) {
        return airlines[_airline].isRegistered;
    }

    function getMultiCallsLength() public view returns(uint){
        return multiCalls.length;
    }

    function getMultiCallsItem(uint _i) public view returns(address){
        return multiCalls[_i];
    }
    function setMultiCallsItem(address _address) public {
        multiCalls.push(_address);
    }

    function clearMultiCalls() public{
        multiCalls = new address[](0);
    }

    function getInsuredInfoFunction(string _flight, address _passenger) external view requireIsOperational returns (uint amount){
        uint index = fetchFlightIndexFunction(_passenger, _flight) - 1;
        if(passengersMapping[_passenger].isPaid[index] == false)
        {
            return passengersMapping[_passenger].insurance[index];
        }
        return 0;
    }
    function fundFunction
                            (  
                                address _airline,
                                uint256 _fund  
                            )
                            public
                            payable
                            requireIsOperational
    {
        airlines[_airline].funds = airlines[_airline].funds.add(_fund);
        balance = balance.add(_fund);
    }
   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   

    function fetchFlightIndexFunction
                                (
                                    address _passenger, 
                                    string memory _flight
                                ) 
                                public 
                                view 
                                returns(uint index)
    {
        string[] memory flights = new string[](5);
        flights = passengersMapping[_passenger].flights;

        for(uint i = 0; i < flights.length; i++){
            if(uint(keccak256(abi.encodePacked(flights[i]))) == uint(keccak256(abi.encodePacked(_flight)))) 
            {
                return(i + 1);
            }
        }

        return(0);
    }


    function getFlightKey
                        (
                            address _airline,
                            string memory _flight,
                            uint256 _timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(_airline, _flight, _timestamp));
    }
}