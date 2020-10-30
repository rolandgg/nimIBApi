import nimIBApi/ibEnums
import nimIBApi/ibContractTypes, nimIBApi/position, nimIBApi/ibMarketDataTypes
import nimIBApi/ibTickTypes, nimIBApi/ibOrderTypes, nimIBApi/ibExecutionTypes
import nimIBApi/orderTracker, nimIBApi/ticker, nimIBApi/ibFundamentalDataTypes
import nimIBApi/client
import nimIBApi/account
import asyncdispatch

export  ibEnums,
        ibContractTypes,
        ibFundamentalDataTypes,
        position,
        ibMarketDataTypes,
        ibTickTypes,
        ibOrderTypes,
        ibExecutionTypes,
        orderTracker,
        ticker,
        client,
        account



if isMainModule:
    var client = newIBClient()
    waitFor client.connect("127.0.0.1", 4002, 1)
    echo client.account.netLiquidation #access the net liquidation value of the account
    var contract = Contract(symbol: "AAPL", secType: SecType.Stock, currency: "USD", exchange: "SMART")
    let details = waitFor client.reqContractDetails(contract) #request contract details
    echo details[0].category #returns Apple's sector classification

    var order = initOrder()
    order.totalQuantity = 10
    order.orderType = OrderType.Market
    order.action = Action.Buy
    var orderTracker = waitFor client.placeOrder(contract, order)