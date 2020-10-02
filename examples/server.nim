import ws, asyncdispatch, asynchttpserver, streams, strutils, parsecsv
import json, sugar, sequtils, tables, times, timezones, math
import ../src/ibApi

# Statistical arbitrage pairs-trading algorithm combined with a web-server streaming data to a brower frontend.
# To make this work you will have to supply your own lists of stocks and pairs to trade.
# This example is work in progress!


type
    EnterSide = enum
        sLong, sShort
    Active = enum
        acNone="-", acLong="Long", acShort="Short"
    TradeStatus = enum
        trSubmit, trActive, trClosed
    Stock = tuple[symbol: string, exchange: string, currency: string]
    Pair = tuple[symbolN: string, symbolD: string, exposure: float, last: float,
                 std: float, mean: float, zscore: float, active: Active]
    Rate = tuple[rebate: float, interest: float]
    Trade = tuple[id: int, symbolN, symbolD: string, qtyN: int, qtyD: int, entryTimeN: string, entryTimeD: string, entryPriceN: float, entryPriceD: float,
                  exitTimeN: string, exitTimeD: string, exitPriceN: float, exitPriceD: float, pnl: float, commission: float,
                  orderN: OrderTracker, orderD: OrderTracker, status: TradeStatus]
    AccountSnapShot = tuple[tstamp: Time, openPnL: float, closedPnL: float, equity: float]



proc midpoint(ticker: Ticker): float {.inline.} =
    return (ticker.bid + ticker.ask) / 2

proc loadStocks(): seq[Stock] =
    var p: CsvParser
    p.open("stocks.csv")
    p.readHeaderRow()
    while p.readRow():
        result.add((symbol: p.rowEntry("Ticker"),
         exchange: p.rowEntry("Exchange"), currency: p.rowEntry("Currency")))

proc loadPairs(): seq[Pair] =
    var p: CsvParser
    p.open("pairs.csv")
    p.readHeaderRow()
    while p.readRow():
        result.add((symbolN: p.rowEntry("Stock1"), symbolD: p.rowEntry("Stock2"),
         exposure: parseFloat(p.rowEntry("Exposure")), last: 0.0, std: 0.0, mean: 0.0, zscore: 0.0, active: acNone))

proc main() =
    # variables
    let ET = tz"America/New_York"
    var ws: WebSocket
    let stocks = loadStocks()
    var contracts: Table[string, Contract] = initTable[string,Contract]()
    for stock in stocks:
        contracts[stock.symbol] = Contract(symbol: stock.symbol, secType: SecType.Stock, currency: stock.currency, exchange: stock.exchange)
    var pairs = loadPairs()
    var client = newIBClient()
    var tickers: Table[string,Ticker] = initTable[string,Ticker]()
    var priceData: Table[string,BarSeries] = initTable[string,BarSeries]()
    var rates: Table[string,Rate] = initTable[string,Rate]()
    var openTrades: Table[int,Trade] = initTable[int,Trade]()
    var closedTrades: seq[Trade] = @[]
    var accountHistory: seq[AccountSnapShot] = @[(tstamp: now().toTime, openPnL: 0.0, closedPnL: 0.0, equity: 0.0)]
    var equity, openPnL, closedPnL: float
    var nextTradeId = 0
    var runTrading = false
    var marketOpen: DateTime
    var marketClose: DateTime
    var tradingTime: DateTime
    var marketClosed = true
    var checkHours = true
    var doTrading = false

    # closure functions

    proc initTrade(symbolN, symbolD: string, trackerN: OrderTracker, trackerD: OrderTracker): Trade =
        inc nextTradeId
        result.id = nextTradeId
        result.symbolN = symbolN
        result.symbolD = symbolD
        result.orderN = trackerN
        result.orderD = trackerD
        result.status = trSubmit

    proc setTodaysTradingHours() {.async.} =
        let etTime = inZone(now(), ET)
        if etTime.weekday in [dSat, dSun]:
            marketClosed = true
            return
        let details = await client.reqContractDetails(contracts[stocks[0].symbol]) # any stock will do
        let calendar = parseLiquidHours(details[0])
        for day in calendar:
            if day.marketOpen.yearday == etTime.yearday:
                marketOpen = day.marketOpen
                marketClose = day.marketClose
                tradingTime = marketClose - initTimeInterval(minutes = 30)
                marketClosed = false
                return
        marketClosed = true

    proc connectIB() {.async.} =
        if not (client.isConnected):
            asyncCheck client.connect("127.0.0.1", 4002, 1) 
    
    proc disconnectIB() =
        if client.isConnected:
            client.disconnect()

    proc loadRates() {.async.} =
        var file = newFileStream("usa.txt", fmRead)
        var line: string
        while readLine(file,line):
            let data = line.split("|")
            if contracts.hasKey(data[0]):
                rates[data[0]] = (rebate: parseFloat(data[5]), interest: parseFloat(data[6]))
    
    proc sendRates(){.async.} =
        for stock,rate in rates.pairs:
            var payload = %*{"Id": "rate", "Symbol": stock, "Rebate": rate.rebate, "Interest":rate.interest}
            await ws.send($payload)

    proc sendPair(pair: Pair) {.async.} =
        await ws.send($(%*{"Id": "pair", "Pair": pair.symbolN & "." & pair.symbolD, "Exposure": pair.exposure,
        "Last": pair.last, "Mean": pair.mean, "Std": pair.std, "Zscore": pair.zscore, "Active": $pair.active}))

    proc onTick(tick: Ticker) {.async.} =
        var payload = %*{"Id": "price", "Symbol": tick.contract.symbol, "Bid": tick.bid, "Ask": tick.ask,
         "BidSize": tick.bidSize, "AskSize": tick.askSize, "Shortable": $(tick.difficultyToShort), "ShortShares": tick.shortableShares}
        await ws.send($payload)

    proc subscribeRealTimeData() {.async.} =
        for stock in contracts.keys:
            echo stock
            tickers[stock] = await client.reqMktData(contracts[stock], false, false,@[GenericTickType.ShortableData], onTick)

    proc loadPriceData() {.async.} =
        for stock in contracts.keys:
            priceData[stock] = await client.reqHistoricalData(contracts[stock], "20 D", "1 day", "ADJUSTED_LAST", true)

    proc calculateSignals() {.async.} =
        waitFor loadPriceData()
        for pair in pairs.mitems:
            let stockN = pair.symbolN
            let stockD = pair.symbolD
            let nBars = priceData[stockN].data.len
            if not(priceData.hasKey(stockN) and priceData.hasKey(stockD)):
                return
            var spread: seq[float] = newSeqofCap[float](nBars)
            for i in 0..nBars-1:
                spread.add(priceData[stockN].data[i].close / priceData[stockD].data[i].close)
            var mean = 0.0
            var std = 0.0
            var last = spread[^1]

            for bar in spread:
                mean += bar

            mean /= float(nBars)

            for bar in spread:
                std += (bar - mean)*(bar - mean)

            std /= float(nBars)

            pair.last = last
            pair.mean = mean
            pair.std = sqrt(std)
            pair.zscore = sqrt((last - mean)*(last - mean) / std)

    proc enter(symbolN, symbolD: string, side: EnterSide ) {.async.} =
        var exposure: float
        for pair in pairs:
            if pair.symbolN == symbolN and pair.symbolD == symbolD:
                exposure = pair.exposure
        # nominator leg
        var order = initOrder()
        order.totalQuantity = float(int(exposure / tickers[symbolN].midpoint))
        order.orderType = OrderType.MarketOnClose
        if side == sLong:
            order.action = Action.Buy
        else:
            order.action = Action.Sell
        var orderTrackerN = await client.placeOrder(contracts[symbolN], order)
        # denominator leg
        order.totalQuantity = float(int(exposure / tickers[symbolD].midpoint))
        if side == sLong:
            order.action = Action.Sell
        else:
            order.action = Action.Buy
        var orderTrackerD = await client.placeOrder(contracts[symbolD], order)
        let trade = initTrade(symbolN, symbolD, orderTrackerN, orderTrackerD)
        openTrades[trade.id] = trade

    proc close(trade: var Trade) {.async.} =
        var order = initOrder()
        order.orderType = OrderType.MarketOnClose
        order.totalQuantity = float(abs(trade.qtyN))
        if trade.qtyN != 0:
            if trade.qtyN > 0:
                order.action = Action.Sell
            elif trade.qtyN < 0:
                order.action = Action.Buy
            trade.orderN = await client.placeOrder(contracts[trade.symbolN],order)
        if trade.qtyD != 0:
            if trade.qtyD > 0:
                order.action = Action.Sell
            elif trade.qtyD < 0:
                order.action = Action.Buy
            trade.orderD = await client.placeOrder(contracts[trade.symbolD],order)
    
    proc placeOrders() {.async.} =
        for pair in pairs.mitems:
            # check trades to close
            if pair.active == acLong and pair.last < pair.mean:
                for id,trade in openTrades.mpairs:
                    if trade.symbolN == pair.symbolN and trade.symbolD == pair.symbolD:
                        asyncCheck close(trade)
                pair.active = acNone
            if pair.active == acShort and pair.last > pair.mean:
                for id,trade in openTrades.mpairs:
                    if trade.symbolN == pair.symbolN and trade.symbolD == pair.symbolD:
                        asyncCheck close(trade)
                pair.active = acNone
            if pair.active == acNone and pair.zscore < -2:
                asyncCheck enter(pair.symbolN, pair.symbolD, sLong)
            if pair.active == acNone and pair.zscore > 2:
                asyncCheck enter(pair.symbolN, pair.symbolD, sShort)  

    proc updateState() {.async.} =
        var markForDelete: seq[int] = @[]
        for id,trade in openTrades.mpairs:
            case trade.status
            of trSubmit:
                if trade.orderN != nil:
                    if trade.orderN.isFilled:
                        trade.qtyN = int(trade.orderN.qtyFilled)
                        trade.entryPriceN = trade.orderN.avgFillPrice
                        trade.entryTimeN = trade.orderN.fillTime
                        trade.commission += trade.orderN.commission 
                        trade.orderN = nil
                if trade.orderD != nil:
                    if trade.orderD.isFilled:
                        trade.qtyD = int(trade.orderD.qtyFilled)
                        trade.entryPriceD = trade.orderD.avgFillPrice
                        trade.entryTimeD = trade.orderD.fillTime
                        trade.commission += trade.orderD.commission 
                        trade.orderD = nil
                if trade.orderD == nil and trade.orderN == nil:
                    trade.status = trActive
            of trActive:
                if trade.orderN != nil:
                    if trade.orderN.isFilled:
                        trade.exitPriceN = trade.orderN.avgFillPrice
                        trade.exitTimeN = trade.orderN.fillTime
                        trade.commission += trade.orderN.commission 
                        trade.orderN = nil
                if trade.orderD != nil:
                    if trade.orderD.isFilled:
                        trade.exitPriceD = trade.orderD.avgFillPrice
                        trade.exitTimeD = trade.orderD.fillTime
                        trade.commission += trade.orderD.commission 
                        trade.orderD = nil
                if trade.orderD == nil and trade.orderN == nil:
                    trade.status = trClosed
            else:
                discard
            if trade.status == trClosed:
                trade.pnl = float(trade.qtyD)*(trade.exitPriceD - trade.entryPriceD)
                trade.pnl += float(trade.qtyN)*(trade.exitPriceN - trade.entryPriceN)
                trade.pnl -= trade.commission
                closedTrades.add(trade)
                markForDelete.add(trade.id)
        for id in markForDelete:
            openTrades.del(id)
        equity = 0
        openPnL = 0
        closedPnL = 0
        for trade in closedTrades:
            closedPnL += trade.pnl
        equity += closedPnL
        for id, trade in openTrades.mpairs:
            trade.pnl = float(trade.qtyD)*(tickers[trade.symbolD].lastTrade - trade.entryPriceD)
            trade.pnl += float(trade.qtyN)*(tickers[trade.symbolN].lastTrade - trade.entryPriceN)
            trade.pnl -= trade.commission
            openPnL += trade.pnl
        equity += openPnL

    proc run() {.async.} =
        while runTrading:
            let etTime = inZone(now(),ET)
            if checkHours and etTime.hour == 8 and etTime.minute == 0:
                await setTodaysTradingHours()
                checkHours = false
                if not(marketClosed):
                    doTrading = true
            if doTrading:
                if etTime.hour == tradingTime.hour and etTime.minute == tradingTime.minute:
                    await calculateSignals()
                    await placeOrders()
                    doTrading = false
            if etTime.hour == 18 and etTime.minute == 0:
                checkHours = true
            await updateState()
            await sleepAsync(59_000)

    proc cb(req: Request) {.async, gcsafe.} =
        if req.url.path == "/ws":
            ws = await newWebSocket(req)
            echo "Connection received!"
            asyncCheck loadRates()
            asyncCheck sendRates()
            for pair in pairs:
                asyncCheck sendPair(pair)
            while ws.readyState == Open:
                try:
                    let packet = await ws.receiveStrPacket()
                    if packet == "connect":
                        waitFor connectIB()
                        echo client.isConnected
                        if client.isConnected:
                            await ws.send($(%*{"Id": "connected"}))
                            await subscribeRealTimeData()
                    elif packet == "disconnect":
                        disconnectIB()
                        if not (client.isConnected):
                            await ws.send($(%*{"Id": "disconnected"}))
                    await sleepAsync(100)
                except:
                    echo "Connection closed"
                    return
    
    var server = newAsyncHttpServer()
    waitFor server.serve(Port(9001), cb)

if isMainModule:
    main()

