import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress, config.dataAddress);
        this.initialize(callback);
        this.x = config.appAddress;
        this.y = config.dataAddress;
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            while(this.flights.length < 5) {
                this.flights.push({
                    airline: accts[counter++],
                    flight: "Flight" + Math.floor((Math.random() * 10) + 1),
                    timestamp: randomDate(new Date(), new Date(Date.now() + 1000 * 60 * 60 * 2)),
                });
            }
            callback();
        });
    }
    async buy(insurance, flight, callback){
        let self = this;
        let amount = self.web3.utils.toWei(insurance, "ether").toString();
        await self.flightSuretyApp.methods.buy(insurance, flight).send({ from: this.owner, value: amount,  gas:3000000 }, (error, result) => {
                callback(error, result);
            });

    }

    async pay(callback){
        let self = this;
        await self.flightSuretyApp.methods.pay().send({from: self.owner}, (error, result) => {
                if(error){
                    console.log(error);
                }else {
                    console.log(result);
                    callback(result);
                }
            });
    }
    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }
}