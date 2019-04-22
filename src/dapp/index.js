import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(contract.flights);
            contract.flights.forEach(flight => {
                displayList(flight, DOM.elid("flights"));
            });
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let address = DOM.elid('flight-address').value;
            let time = DOM.elid('flight-time').value;
            // Write transaction
            contract.fetchFlightStatus({address: address, flight: flight, time: time}, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        });

        DOM.elid('purchase').addEventListener('click', () => {
            let flight = DOM.elid('flights').value;
            let insurance = DOM.elid('insurance').value;
            if (insurance > 0) {
                contract.buy(insurance, flight, (error, result) => {
                    alert("Passenger was able to buy insurance.");
                });
            } else {
                alert("Passenger should buy insurance.");
            }
        });

        DOM.elid('flights').addEventListener('change', () => {
            console.log("Hello" + contract.flights);
            return contract.flights;
        });

        DOM.elid('withdraw').addEventListener('click', () => {
            contract.pay((error, result) => {
                console.log("added funds");
                display('Withdrwaw', 'Get insurance.', [ { label: 'Get funds', error: error, value: 'success' } ]);
           });
        });


    });    
})()

function displayList(flight, parentEl) {
    console.log(flight);
    console.log(parentEl);
    let el = document.createElement("option");
    el.text = `${flight.flight} - ${new Date((flight.timestamp))}`;
    el.value = JSON.stringify(flight);
    parentEl.add(el);
}


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}