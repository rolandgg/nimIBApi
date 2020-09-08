import ibApi
import asyncdispatch

var client = newIBClient()
waitFor client.connect("127.0.0.1", 4002, 1)
echo client.account.netLiquidation #access the net liquidation value of the account
var contract = Contract(symbol: "AAPL", secType: SecType.Stock, currency: "USD", exchange: "SMART")
let details = waitFor client.reqContractDetails(contract) #request contract details
echo parseLiquidHours(details[0])
waitFor sleepAsync(1_000)