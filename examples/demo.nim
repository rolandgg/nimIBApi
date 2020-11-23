import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os

var client = newIBClient()
waitFor client.connect("127.0.0.1", 4002, 1)
echo client.account.netLiquidation #access the net liquidation value of the account

        
var contract = Contract(symbol:"AAPL", secType: SecType.Stock, currency: "USD", exchange: "SMART")
var details = waitFor client.reqContractDetails(contract)
var fundamentalData = waitFor client.reqFundamentalData((details[0]).contract, FundamentalDataType.FinStatements)
echo fundamentalData.totalAssets # total Assets (latest)
echo fundamentalData.gpm # gross profit margin (trailing twelve months)

# var order = initOrder()
# order.totalQuantity = 10
# order.orderType = OrderType.Market
# order.action = Action.Buy
# var orderTracker = waitFor client.placeOrder(contract, order)
# waitFor sleepAsync(10_000)

# var ticker = waitFor client.reqMktData(contract, false, false, @[GenericTickType.ShortableData])
# waitFor sleepAsync(2_000) # wait a bit for ticks to come in
# echo ticker.bid
# echo ticker.ask # access the current bid/ask prices
# echo ticker.marketDataSetting
# waitFor client.reqMarketDataType(MarketDataType.Delayed)
# waitFor sleepAsync(2_000)
# echo ticker.marketDataSetting