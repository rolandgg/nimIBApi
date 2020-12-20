import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os

var client = newIBClient()
waitFor client.connect("127.0.0.1", 4002, 1)
echo client.account.netLiquidation #access the net liquidation value of the account

var contractList = waitFor client.reqMatchingSymbol("SANOFI ORD")
for contract in contractList:
    echo contract.contract.symbol & ": " & contract.contract.primaryExchange & ": " & contract.contract.currency
    var details = waitFor client.reqContractDetails(contract.contract)
    echo details[0].secIdList
    echo details[0].longName     
#var contract = Contract(symbol:"SIE", secType: SecType.Stock, currency: "EUR", exchange: "SMART")
#var details = waitFor client.reqContractDetails(contract)
#echo details[0].secIdList
#var fundamentalData = waitFor client.reqFundamentalData((details[0]).contract, FundamentalDataType.FinStatements)

#fundamentalData.save("SIE.xml")
#echo fundamentalData.totalAssets # total Assets (latest)
#echo fundamentalData.gpm # gross profit margin (trailing twelve months)

# var order = initOrder()
# order.totalQuantity = 10
# order.orderType = OrderType.Market
# order.action = Action.Buy
# var orderTracker = waitFor client.placeOrder(contract, order)
# waitFor sleepAsync(10_000)
#waitFor client.reqMarketDataType(MarketDataType.Delayed)
#var ticker = waitFor client.reqMktData(contract, false, false, @[GenericTickType.ShortableData])

#waitFor sleepAsync(2_000) # wait a bit for ticks to come in
#echo ticker.bid
#echo ticker.ask # access the current bid/ask prices
# echo ticker.marketDataSetting
# waitFor client.reqMarketDataType(MarketDataType.Delayed)
# waitFor sleepAsync(2_000)
# echo ticker.marketDataSetting