# order-send-common-mt4
This library contains common code necessary to run the order-send component on MT4.

## Installation
To install this library, simply clone the repository to your /MQL4/Include directory.

## Library Contents
This library contains a number of files that are useful, not only for running the order-send package, but for general MQL4 programming as well. This section contains a description of those libraries:

### Socket Communication
The `ClientSocket`, `ServerSocket` and `SocketCommon` libraries exist to allow socket communication in MQL4. These are intended to allow low-level TCP communications.

### Prime Numbers
The `Primes` library allows for generation and confirmation of prime numbers.

### MQL Trade Request
The `TradeRequest` library contains a type that describes an order made on MT4, mimicing the `MqlTradeRequest` object from MQL5.
