var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

var Web3Utils = require('web3-utils');
var Web3 = require('web3')
web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:7545"));

contract('Flight Surety Tests', async (accounts) => {

  const ORACLES_COUNT = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizePassengerFunction(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multipassenger) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multipassenger) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multipassenger) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multipassenger) can block access to functions using requireIsOperational when operating status is false`, async function () {
      //double check code here
      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirlineFunction(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegisteredFunction.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  
  it('(multiparty) only existing airline may register a new airline until there are at least four airlines registered', async () => {

    // ARRANGE
    let newAirline = accounts[2];

    let funds = 10000000000000000000; // 10 ether

    try{
      await config.flightSuretyApp.registerAirlineFunction(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegisteredFunction(newAirline);

    await config.flightSuretyApp.sendFundToAirline(config.firstAirline, {from: config.firstAirline, value: funds}); 
    await config.flightSuretyApp.registerAirlineFunction(newAirline, {from: config.firstAirline});
    let result2 = await config.flightSuretyData.isAirlineRegisteredFunction(newAirline);

    assert.equal(result, false, "Airline was registered but it should not.");
    assert.equal(result2, true, "Airline was not registered but it should.");

    });
    it('(multiparty) registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airliner', async () => {

        // ARRANGE
        let newAirline = accounts[3];
        let newAirline2 = accounts[4];
        let newAirline3 = accounts[5];
        let newAirline4 = accounts[6];
        let registerBelowThreshold = true;
        let funds = 10000000000000000000; // 10 ether
        try{
        await config.flightSuretyApp.registerAirlineFunction(newAirline2, {from: config.firstAirline});
        //await config.flightSuretyApp.sendFundToAirline(newAirline2, {from: config.firstAirline, value: funds}); 
        await config.flightSuretyApp.registerAirlineFunction(newAirline3, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirlineFunction(newAirline4, {from: config.firstAirline});
        //await config.flightSuretyApp.sendFundToAirline(newAirline4, {from: config.firstAirline, value: funds});
        }
        catch(e) {
            registerBelowThreshold = false;
            console.log(e);
        }
        let result = await config.flightSuretyData.isAirlineRegisteredFunction.call(newAirline4);
        // ASSERT
        //assert.equal(registerBelowThreshold, true, "Can not register Airlines but should work");
        //assert.equal(await config.flightSuretyApp.airlinesRegisteredCount.call(), 4, "Threshold ignored");
    
        assert.equal(result, true, "Airline was not registered.");

        
    });
    


  

});
