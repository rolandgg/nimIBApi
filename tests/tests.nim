import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os
import unittest

## Running the test suite requires a connected Gateway on port 4002

suite "Value type requests":
    setup:
        var client = newIBClient()
        waitFor client.connect("127.0.0.1", 4002, 1)
    teardown:
        client.disconnect()

    test "Contract Details":
        let contract = Contract(symbol:"SIE", secType: SecType.Stock, currency: "EUR", exchange: "SMART")
        var details = waitFor client.reqContractDetails(contract)
        check(details.len > 0)

    test "Matching Symbols":
        var contractList = waitFor client.reqMatchingSymbol("Sanofi")
        check(contractList.len > 0)

    test "Fundamental Data":
        let contract = Contract(symbol:"SIE", secType: SecType.Stock, currency: "EUR", exchange: "SMART")
        var report = waitFor client.reqFundamentalData(contract, FundamentalDataType.FinStatements)
        check(report.kind == FundamentalDataType.FinStatements)
    
    test "Historical Data":
        let contract = Contract(symbol:"AAPL", secType: SecType.Stock, currency: "USD", exchange: "SMART")
        when defined(USRealtime):
            let bars = waitFor client.reqHistoricalData(contract, "1 M", "1 day", "MIDPOINT", true)
            check (bars.data.len > 0)
        else:
            expect(IBError):
                let bars = waitFor client.reqHistoricalData(contract, "1 M", "1 day", "MIDPOINT", true)


    
    
