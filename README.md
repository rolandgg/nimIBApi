# nimIBApi
This is a Nim (www.nim-lang.org) client for the Interactive Brokers TraderWorkstation/Gateway API. It is a native implementation of the TCP socket messaging protocol and not a wrapper of the official C++ API, thus avoiding its implementation flaws (like messages potentially getting stuck in an internal buffer).

The client uses Nim's single-threaded async I/O framework to wrap the asyncronous, streaming socket communication and exposes a RESTlike API.

This project is work in progress. So far, the following functionality is supported:

* Receive account data
* Query contract details
* Basic order types (Market, Limit, Market-On-Close)
* Subscribe to real-time data (price and shortsale data)
* Request historical bar data

It was only tested for trading stocks on US exchanges and against Gateway version 978, legacy API versions are not supported.

If you use this in a trading application, bear in mind that the client is single-threaded and constantly needs to keep spinning in order to process incoming messages in a timely manner. Thus, always use `sleepAsync` to avoid blocking the event loop.

## Examples

Connecting a client to the Gateway will immediately subscribe to account updates. The client will automatically keep the account state up-to-date, no API requests are needed. The account data can be accessed once the connection process is completed. In the example below, we define a contract for Apple stock on US exchanges and query contract details for it.

```nim
include ibApi

var client = newIBClient()
waitFor client.connect("127.0.0.1", 4002, 1)
echo client.account.netLiquidation #access the net liquidation value of the account
var contract = Contract(symbol: "AAPL", secType: SecType.Stock, currency: "USD", exchange: "SMART")
let details = waitFor client.reqContractDetails(contract) #request contract details
echo details[0].industry #returns Apple's industry sector classification
```

To place an order, we also need to define an order object. The `placeOrder` function will return an `OrderTracker` reference, which will be updated automatically and allows to track the order execution process.

```nim
#buy 10 shares of Apple
order.totalQuantity = 10
order.orderType = OrderType.Market
order.action = Action.Buy
var orderTracker = waitFor client.placeOrder(contract, order)
```

Likewise, requesting real-time market data will return a `Ticker` reference that will automatically be updated with incoming market price ticks.

```nim
#request top-of-book real-time data for Apple, including data on availability to short
var ticker = waitFor client.reqMktData(contract, false, false, @[GenericTickType.ShortableData])
waitFor sleepAsync(10_000) # wait a bit for ticks to come in
echo ticker.bid
echo ticker.ask # access the current bid/ask prices
```