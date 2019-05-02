pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint8;
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint256 public constant INSURANCE_BUYIN= 10 ether;
    uint256 private constant INSURANCE_MAX_PAYMENT = 1 ether;
    uint256 private constant MULTIPARTY_CONSENSUS_THRESHOLD = 4;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    FlightSuretyData flightSuretyData;

    uint8 public airlinesRegisteredCount;
    mapping(address => address[]) private airlineVotes;

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
        require(isOperational(), "Contract is currently not operational");
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

    modifier requireIsCallerAirlineRegistered()
    {
        require(flightSuretyData.isCallerAirlineRegistered(msg.sender), "Caller not registered");
        _;
    }

    modifier requireIsCallerAirlineFunded()
    {
        require(flightSuretyData.isCallerAirlineFunded(msg.sender), "Caller can not participate in contract until it submits funding");
        _;
    }

    modifier requireFlightNotInsured(address airline, string flightNumber, uint256 timestamp)
    {
        require(!flightSuretyData.isFlightInsured(msg.sender, airline, flightNumber, timestamp), "Flight already insured");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address _data
                                )
                                public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(_data);
        airlinesRegisteredCount = 1;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return flightSuretyData.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                            (
                                address _airline
                            )
                            external
                            requireIsOperational
                            //requireIsCallerAirlineRegistered
                            requireIsCallerAirlineFunded
    {
        bool success = false;

        if(airlinesRegisteredCount < MULTIPARTY_CONSENSUS_THRESHOLD) {
            success = flightSuretyData.registerAirline(msg.sender, _airline);
            if(success) {
                airlinesRegisteredCount++;
            }
        } else {
            bool isDuplicate = false;

            for(uint c = 0; c < airlineVotes[_airline].length; c++) {
                if (airlineVotes[_airline][c] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Multivotes not allowed");

            airlineVotes[_airline].push(msg.sender);
            if (airlineVotes[_airline].length >= airlinesRegisteredCount.div(2)) {

                success = flightSuretyData.registerAirline(msg.sender, _airline);
                if(success) {
                    airlinesRegisteredCount++;
                }

                airlineVotes[_airline] = new address[](0);
            }
        }
    }

    function fund
                            (
                            //address _airline
                            )
                            public
                            payable
                            requireIsOperational
    {
        //require(msg.value >= INSURANCE_BUYIN, "TESTTTTTT");

        //flightSuretyData.fundAirline(_airline, msg.value);
        address(flightSuretyData).transfer(msg.value);
        flightSuretyData.fundAirline(msg.sender);
    }

    function insuredBalance
                            (
                            )
                            external
                            view
                            requireIsOperational
                            returns (uint256)
    {
        return flightSuretyData.insuredBalance(msg.sender);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight
                                (
                                    address _airline,
                                    string _flightNumber,
                                    uint256 _timestamp
                                )
                                public
                                payable
                                requireIsOperational
                                requireFlightNotInsured(_airline, _flightNumber, _timestamp)
    {
        require(msg.value <= INSURANCE_MAX_PAYMENT, "The insurance maximum payment has been exceeded");

        // Transfer Payment to Data Contract
        address(flightSuretyData).transfer(msg.value);

        flightSuretyData.buy(msg.sender, _airline, _flightNumber, _timestamp, msg.value);
    }

    function withdraw
                            (
                            )
                            external
                            requireIsOperational
    {
        flightSuretyData.pay(msg.sender);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
                                (
                                    address _airline,
                                    string memory _flightNumber,
                                    uint256 _timestamp,
                                    uint8 _statusCode
                                )
                                internal
                                requireIsOperational
    {
        if(_statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditinsureds(_airline, _flightNumber, _timestamp);
        }
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address _airline,
                            string _flight,
                            uint256 _timestamp
                        )
                        external
                        requireIsOperational
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, _airline, _flight, _timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isValid: true,
                                                isOpen: true
                                            });

        emit OracleRequest(index, _airline, _flight, _timestamp);
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
        bool isValid;                                   // If valid, oracle responses are accepted
        bool isOpen;                                    // If open, oracle responses are not finished
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
                            requireIsOperational
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
                            requireIsOperational
                            returns(uint8[3])
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
                            uint8 _index,
                            address _airline,
                            string _flight,
                            uint256 _timestamp,
                            uint8 _statusCode
                        )
                        external
                        requireIsOperational
    {
        require((oracles[msg.sender].indexes[0] == _index) || (oracles[msg.sender].indexes[1] == _index) || (oracles[msg.sender].indexes[2] == _index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(_index, _airline, _flight, _timestamp));
        require(oracleResponses[key].isValid, "Flight or timestamp do not match oracle request");

        if(oracleResponses[key].isOpen) {
            oracleResponses[key].responses[_statusCode].push(msg.sender);

            // Information isn't considered verified until at least MIN_RESPONSES
            // oracles respond with the *** same *** information
            emit OracleReport(_airline, _flight, _timestamp, _statusCode);
            if (oracleResponses[key].responses[_statusCode].length >= MIN_RESPONSES) {

                // if Response is verified close request
                oracleResponses[key].isOpen = false;

                emit FlightStatusInfo(_airline, _flight, _timestamp, _statusCode);

                // Handle flight status as appropriate
                processFlightStatus(_airline, _flight, _timestamp, _statusCode);
            }
        }
    }


    function getFlightKey
                        (
                            address _airline,
                            string _flight,
                            uint256 _timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(_airline, _flight, _timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address _account
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(_account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(_account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(_account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address _account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), _account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  
        }

        return random;
    }

// endregion

}

contract FlightSuretyData {
    address [] public insureds;

    function isOperational() public view returns(bool);
    function isCallerAirlineRegistered(address _originSender) public view returns (bool);
    function isCallerAirlineFunded(address _originSender) public view returns (bool);
    function isFlightInsured(address _originSender, address _airline, string _flightNumber, uint256 _timestamp) public view returns (bool);

    function registerAirline(address _originSender, address _airline) external returns (bool success);
    function fundAirline(address _airline) external;

    function fetchinsuredAmount(address _originSender,address _airline,string _flightNumber,uint256 _timestamp) external view returns (uint256);

    function insuredBalance(address _originSender) external view returns (uint256);
    function buy(address _originSender, address _airline, string _flightNumber, uint256 _timestamp, uint256 _amount) external;
    function creditinsureds(address _airline, string _flightNumber, uint256 _timestamp) external;

    function pay(address _originSender) external;
}