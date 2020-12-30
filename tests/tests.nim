import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os
import unittest

## Running the test suite requires a connected Gateway on port 4002
var client = newIBClient()
waitFor client.connect("127.0.0.1", 4002, 1)
suite "Requests":
  test "Contract Details":
    let contract = Contract(symbol: "SIE", secType: SecType.Stock,
        currency: "EUR", exchange: "SMART")
    var details = waitFor client.reqContractDetails(contract)
    check(details.len > 0)

  test "Matching Symbols":
    var contractList = waitFor client.reqMatchingSymbol("Sanofi")
    check(contractList.len > 0)

  test "Fundamental Data":
    let contract = Contract(symbol: "SIE", secType: SecType.Stock,
        currency: "EUR", exchange: "SMART")
    var report = waitFor client.reqFundamentalData(contract,
        FundamentalDataType.FinStatements)
    check(report.kind == FundamentalDataType.FinStatements)

  test "Historical Data":
    let contract = Contract(symbol: "AAPL", secType: SecType.Stock,
        currency: "USD", exchange: "SMART")
    when defined(USRealtime):
      let bars = waitFor client.reqHistoricalData(contract, "1 M", "1 day",
          "MIDPOINT", true)
      check (bars.data.len > 0)
    else:
      expect(IBError):
        let bars = waitFor client.reqHistoricalData(contract, "1 M", "1 day",
            "MIDPOINT", true)
  test "Available Parameters":
    let params = waitFor client.reqScannerParams()
    check(params.xml.len != 0)

  test "Scanner Subscription":
    var scanner = initScannerSubscription()
    scanner.instrument = "STK"
    scanner.locationCode = "STK.US.MAJOR"
    scanner.scanCode = "TOP_PERC_GAIN"
    scanner.numberOfRows = 10
    let scanResult = waitFor client.reqScannerSubscription(scanner)
    check(scanResult.len == 10)
    
suite "Orders": # run this only during US trading hours

  test "Market Order":
    let contract = Contract(symbol: "AAPL", secType: SecType.Stock,
        currency: "USD", exchange: "SMART")
    var order = initOrder()
    order.totalQuantity = 10
    order.orderType = OrderType.Market
    order.action = Action.Buy
    var orderTracker = waitFor client.placeOrder(contract, order)
    waitForFill orderTracker
    check(orderTracker.qtyFilled == 10.0)
    order.action = Action.Sell
    orderTracker = waitFor client.placeOrder(contract, order)
    waitForFill orderTracker

suite "Market Data":

  test "Delayed":
    let contract = Contract(symbol: "AAPL", secType: SecType.Stock,
        currency: "USD", exchange: "SMART")
    waitFor client.reqMarketDataType(MarketDataType.Delayed)
    var ticker = waitFor client.reqMktData(contract, false, false, @[
        GenericTickType.ShortableData])
    waitFor sleepAsync(2_000)
    check(ticker.bid != ticker.ask)

client.disconnect()





