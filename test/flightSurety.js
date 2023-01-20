
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
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
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
 
  it('(airline) is registered when contract is deployed', async () => {

    let orignialAirline = accounts[0];
    
    let result = await config.flightSuretyData.isAirlineParticipant.call(orignialAirline); 

    // ASSERT
    assert.equal(result, true, "Airline is not registered");

  });
  it('(airline) that exists may register a new airline until there are at least four airlines registered', async () => {
   
    //ACT
    try {
        await config.flightSuretyApp.registerAirline(config.testAddresses[2], "Udacity2", { from: config.firstAirline });
        await config.flightSuretyApp.registerAirline(config.testAddresses[3], "Udacity3", { from: config.firstAirline });
        await config.flightSuretyApp.registerAirline(config.testAddresses[4], "Udacity4", { from: config.firstAirline });
        await config.flightSuretyData.fund({from: config.testAddresses[2],value: web3.utils.toWei('10', "ether")});
        await config.flightSuretyData.fund({from: config.testAddresses[2],value: web3.utils.toWei('10', "ether")});
        await config.flightSuretyData.fund({from: config.testAddresses[2],value: web3.utils.toWei('10', "ether")});
    }

    catch (e) {

    }

    let result2 = await config.flightSuretyData.isAirlineRegistered.call(config.testAddresses[2]);
    let result3 = await config.flightSuretyData.isAirlineRegistered.call(config.testAddresses[3]);
    let result4 = await config.flightSuretyData.isAirlineRegistered.call(config.testAddresses[4]);

    // ASSERT
    assert.equal(result2, true, "Second airline failed registration");
    assert.equal(result3, true, "Third airline failed registration");
    assert.equal(result4, false, "Fourth airline failed registration.");
  });

  it('(airline) can be registered, but does not participate in contract until it submits funding of 10 ether', async () => {
    
    // ARRANGE
    const amt1 = web3.utils.toWei('9', "ether");

    // ACT
    try {
        await config.flightSuretyApp.fundAirline(config.firstAirline, {from: config.firstAirline, value: amt1});
    }
    catch(e) {
        
    }
    let result = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline); 
    
    // ASSERT
    assert.equal(result, false, "Airline was funded with less than 10 ether");
    
});

  //Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines

  //Airline can be registered, but does not participate in contract until it submits funding of 10 ether (make sure it is not 10 wei)


});
