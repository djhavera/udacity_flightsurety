var Web3Utils = require('web3-utils');
var Web3 = require('web3')
web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:7545"));

var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  const ORACLES_COUNT = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
  });


  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(initial) first airline is registered when contract is deployed.`, async function () {
      let result = await config.flightSuretyData.isAirline.call(config.firstAirline);
      assert.equal(result, true, "First airline not registred on deployment");
  });

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyApp.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

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

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

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

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      let status = true;
      try
      {
          status = await config.flightSuretyApp.isOperational.call();
          await config.flightSuretyApp.registerFlight();
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");
      assert.equal(status, false, "Contract is operational");

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    let reverted = false;
    try {
        await config.flightSuretyApp.registerAirline.call(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        reverted = true;
    }

    // ASSERT
    assert.equal(reverted, true, "Airline should not be able to register another airline if it hasn't provided funding");
  });


  it('(airline) fund first airline with sufficient ETH', async () => {
    //let fund = await config.flightSuretyApp.INSURANCE_BUYIN.call();

    // ACT
    let newAirline = accounts[3];
    let reverted = false;
    let balance = 0;
    let fund = 0;
    //let fund = await config.flightSuretyApp.fund(newAirline,{from: config.firstAirline, value: web3.utils.toWei("10", "ether").toString(), gasPrice: 0});
    await config.flightSuretyApp.fund(newAirline,{from: config.firstAirline, value: web3.utils.toWei("10", "ether").toString(), gasPrice: 0});
    // console.log('########## FUND ###########')
    //console.log(fund.toString());
    console.log('########## BALANCE ###########')
    balance = await config.flightSuretyData.getBalance(newAirline,{from: config.firstAirline}).toString();
    console.log(balance.toString());
    try {
        //await config.flightSuretyApp.fund(newAirline,{from: config.firstAirline, value: web3.utils.toWei("10", "ether").toString(), gasPrice: 0});
        await config.flightSuretyApp.registerAirline.call(newAirline, {from: config.firstAirline});
        //await config.flightSuretyApp.registerAirline.call(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        reverted = true;
    }

    // ASSERT
    assert.equal(reverted, false, "Airline could not register.");

  });
 
/*
  it('(airline) can register an Airline using registerAirline() if it is funded', async () => {

    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    let reverted = false;
    try {
        //await config.flightSuretyApp.fund(newAirline,{from: config.firstAirline, value: web3.utils.toWei("10", "ether").toString(), gasPrice: 0});
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        reverted = true;
    }

    // ASSERT
    assert.equal(reverted, false, "Airline could not register.");
  });

  

it('(airline) airlines can register without consensus until M reached', async () => {

    // ARRANGE
    let newAirline2 = accounts[3];
    let newAirline3 = accounts[4];
    let newAirline4 = accounts[5];

    // ACT
    let registerBelowThreshold = true;

    try {
        await config.flightSuretyApp.registerAirline(newAirline2, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(newAirline3, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(newAirline4, {from: config.firstAirline});
    }
    catch(e) {
        registerBelowThreshold = false;
        console.log('############ ERROR#############');
        console.log(e);

    }

    // ASSERT
    assert.equal(registerBelowThreshold, true, "Can not register");
    assert.equal(await config.flightSuretyApp.airlinesRegisteredCount.call(), 4, "You didn't meet the threshold of 4");
  });
*/
 
 

});
