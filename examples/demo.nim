import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os

var client = newIBClient()
waitFor client.connect("127.0.0.1", 4002, 1)
let contract = Contract(symbol: "AAPL", secType: SecType.Stock,
        currency: "USD", exchange: "SMART")
var order = initOrder()
order.totalQuantity = 10
order.orderType = OrderType.Market
order.action = Action.Buy
var orderTracker = waitFor client.placeOrder(contract, order)