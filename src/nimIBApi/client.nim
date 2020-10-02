import asyncnet, asyncfutures, asyncdispatch
import net
import os
import streams, strutils, sequtils
import times
import tables, sets

import utils, message, ibEnums, ibContractTypes, position, ibMarketDataTypes
import ibTickTypes, ibOrderTypes, ibExecutionTypes
import orderTracker, handlers, ticker
import account
include apiConstants

type
    MssgCode = int
    ReqID = int
    TickerID = int
    Portfolio = Table[int, Position]
    Response = ref object
        reqID: ReqID
        mssgCode: MssgCode
        ready: bool
        payload: seq[seq[string]]
    ConnectionState = enum
        csConnecting, csConnected, csDisconnected
    IBClient* = ref object
        logger: FileStream
        socket: AsyncSocket
        conState: ConnectionState
        conTime: Time
        serverTime: Time
        serverVersion*: int
        clientID*: int
        optionalCapabilities*: string
        accountList: seq[string]
        account*: Account
        portfolio*: Portfolio
        listenerTask: Future[void]
        keepAliveTask: Future[void]
        requests: Table[MssgCode, seq[int]]
        responses: Table[int, Response]
        orders: Table[OrderID, OrderTracker]
        tickers: Table[TickerID, Ticker]
        tickerUpdateHandlers: Table[TickerID, proc(ticker: Ticker) {.async.} ]
        orderUpdateHandlers: Table[OrderID, proc(order: OrderTracker)]
        accountUpdateHandler: proc(account: Account)
        positionUpdateHandler: proc(portfolio: Portfolio)
        nextReqID: ReqID
        nextOrderID: OrderID
        nextTickerID: TickerID


proc isConnected*(self: IBClient): bool =
    if self.conState == csConnected:
        return true
    else:
        return false
## Handlers

# Handlers for messages for which no requests are exposed

proc handleManagedAcctsMsg(self: IBClient, payload: seq[string]) =
    self.accountList = payload[1].split(",")

proc handleCurrentTimeMsg(self: IBClient, payload: seq[string]) =
    self.serverTime = fromUnix(parseInt(payload[1]))
    echo "Heartbeat at " & $self.serverTime

proc handleNextOrderIdMsg(self: IBClient, payload: seq[string]) =
    self.nextOrderID = parseInt(payload[1])
    echo "Next reqId received " & $self.nextReqID

proc handleAcctValueUpdateMsg(self: IBClient, payload: seq[string]) =
    let key = payload[1]
    case key
    of "AccountCode":
        self.account.accountCode = payload[2]
    of "AccountType":
        self.account.accountType = payload[2]
    of "CashBalance":
        if payload[3] == "BASE":
            self.account.cashBalance = parseFloat(payload[2])
    of "EquityWithLoanValue":
        self.account.equityWithLoanValue = parseFloat(payload[2])
    of "ExcessLiquidity":
        self.account.excessLiquidity = parseFloat(payload[2])
    of "NetLiquidation":
        self.account.netLiquidation = parseFloat(payload[2])
    of "RealizedPnL":
        if payload[3] == "BASE":
            self.account.realizedPnL = parseFloat(payload[2])
    of "UnrealizedPnL":
        if payload[3] == "BASE":
            self.account.unrealizedPnL = parseFloat(payload[2])
    of "TotalCashBalance":
        if payload[3] == "BASE":
            self.account.totalCashBalance = parseFloat(payload[2])
    else:
        discard

proc handleAcctUpdateEndMsg(self: IBClient, payload: seq[string]) =
    if self.account.accountCode == payload[1]:
        self.account.updated = true
        if not(isNil(self.accountUpdateHandler)):
            self.accountUpdateHandler(self.account)

proc handleAcctUpdateTimeMsg(self: IBClient, payload: seq[string]) =
    self.account.updateTime = payload[1]

proc handlePortfolioValueMsg(self: IBClient, payload: seq[string]) =
    let version = parseInt(payload[0])
    let conId = parseInt(payload[1])
    if not self.portfolio.hasKey(conId): # add position if it does not exist
        self.portfolio[conID] = Position()
        var contract: Contract
        contract.conId = conId
        contract.symbol = payload[2]
        contract.secType = parseEnum[SecType](payload[3])
        contract.lastTradeDateOrContractMonth = payload[4]
        contract.strike = parseFloat(payload[5])
        contract.right = OptionRight(parseInt(payload[6]))
        if version > 7:
            contract.multiplier = payload[7]
            contract.primaryExchange = payload[8]
        contract.currency = payload[9]
        contract.localSymbol = payload[10]
        if version > 8:
            contract.tradingClass = payload[11]
        self.portfolio[conID].contract = contract

    self.portfolio[conId].position = parseFloat(payload[12])
    if self.portfolio[conID].position == 0: # if position is zero, remove from the table
        self.portfolio.del(conID)
        return
    self.portfolio[conId].marketPrice = parseFloat(payload[13])
    self.portfolio[conId].marketValue = parseFloat(payload[14])
    self.portfolio[conId].averageCost = parseFloat(payload[15])
    self.portfolio[conId].unrealizedPnL = parseFloat(payload[16])
    self.portfolio[conId].realizedPnL = parseFloat(payload[17])

proc handleExecutionDataMsg(self: IBClient, payload: seq[string]) =
    let exec = handle[Execution](payload)
    let orderId = exec.orderId
    if self.orders.hasKey(orderId):
        self.orders[orderId].executions.add(exec)

proc handleCommissionReportMsg(self: IBClient, payload: seq[string]) =
    let com = handle[CommissionReport](payload)
    for orderId,order in self.orders.pairs: # this is potentially dangerous! assuming that execution data will always arrive before the commission report!
        for exec in order.executions:
            if exec.execId == com.execId:
                order.commissionReports.add(com)

proc handleOrderStatusUpdateMsg(self: IBClient, payload: seq[string]) =
    var fields = newFieldStream(payload)
    var orderStatus: OrderStatus
    var orderId: int
    orderId << fields
    if self.orders.hasKey(orderId):
        orderStatus.status << fields
        orderStatus.filled << fields
        orderStatus.remaining << fields
        orderStatus.avgFillPrice << fields
        orderStatus.permId << fields
        orderStatus.parentId << fields
        orderStatus.lastFillPrice << fields
        orderStatus.clientId << fields
        orderStatus.whyHeld << fields
        self.orders[orderId].orderStatus = orderStatus

proc handleOpenOrderUpdateMsg(self: IBClient, payload: seq[string]) =
    let tracker = handle[OrderTracker](payload)
    let orderId = tracker.order.orderId
    if self.orders.hasKey(orderId):
        self.orders[orderId].contract = tracker.contract
        self.orders[orderId].order = tracker.order
        self.orders[orderId].orderState = tracker.orderState
    else:
        self.orders[orderId] = tracker

proc handleTickMsg(self: IBClient, payload: seq[string], id: TickerID, msgCode: Incoming) =
    case msgCode
    of Incoming.TICK_PRICE:
        let priceTick = handle[PriceTick](payload)
        case priceTick.kind:
        of TickType.Bid, TickType.DelayedBid:
            self.tickers[id].bid = priceTick.price
            self.tickers[id].bidSize = priceTick.size
        of TickType.Ask, TickType.DelayedAsk:
            self.tickers[id].ask = priceTick.price
            self.tickers[id].askSize = priceTick.size
        of TickType.Last, TickType.DelayedLast:
            self.tickers[id].lastTrade = priceTick.price
            self.tickers[id].lastTradeSize = priceTick.size
        else:
            discard
    of Incoming.TICK_SIZE:
        let sizeTick = handle[SizeTick](payload)
        case sizeTick.kind:
        of TickType.BidSize, TickType.DelayedBidSize:
            self.tickers[id].bidSize = sizeTick.size
        of TickType.Asksize, TickType.DelayedAskSize:
            self.tickers[id].askSize = sizeTick.size
        of TickType.LastSize, TickType.DelayedLastSize:
            self.tickers[id].lastTradeSize = sizeTick.size
        of TickType.ShortableShares:
            self.tickers[id].shortableShares = sizeTick.size
        else:
            discard
    of Incoming.TICK_GENERIC:
        let genericTick = handle[GenericTick](payload)
        case genericTick.kind:
        of TickType.Shortable:
            self.tickers[id].setShortDifficulty(genericTick.value)
        else:
            discard
    else:
        discard
    if self.tickerUpdateHandlers.hasKey(id):
        asyncCheck self.tickerUpdateHandlers[id](self.tickers[id])


proc registerReq(self: IBClient, reqID: ReqID, mssgCode: MssgCode) =
    ## adds the request both to the pending requests and pending responses tables
    if not(self.requests.hasKey(mssgCode)):
        self.requests[mssgCode] = @[]
    self.requests[mssgCode].add(reqID)
    self.responses[reqID] = nil

proc readMessage(self: IBClient): Future[tuple[id: int, payload: seq[string]]] {.async.} =

    # We use a buffered socket so that recv will block until the requested number of bytes is received.
    # This is important, because otherwise the asyncio based architecture will not work,
    # recv() would never block, and thus the listen routine would never be suspended and block outgoing messages
    # from being sent across the socket.
    # Now, the problem is, we always need to know how many bytes to receive, otherwise we end up waiting forever.
    # With v100plus communication, this is possible, we just read the message header first and then the payload.
    # I have no clue why they did not just put a newline at the end of each message, but they didn't!
    # This has the added benefit that we are guaranteed to receive the full message and we don't need to buffer cut-in-half messages.
    # --> Compare the official python, C++ APIs.
    var buf: string
    buf = await self.socket.recv(4)
    let size = readHeader(buf)
    buf = await self.socket.recv(size)
    let fields = buf.split("\0")
    return (id: parseInt(fields[0]), payload: fields[1..^2])

proc retrieve[T](self: IBClient, reqId: int): Future[seq[T]] {.async.} =
    while self.responses[reqID].isNil:
        await sleepAsync(5)
    while not(self.responses[reqID].ready):
        await sleepAsync(5)
    result = @[]
    for line in self.responses[reqId].payload:
        result.add(handle[T](line))
    self.responses.del(reqId)

proc retrieveOrder(self: IBClient, orderId: int): Future[OrderTracker] {.async.} =
    while not (self.orders.hasKey(orderId)):
        await sleepAsync(5)
    result = self.orders[orderId]

proc retrieveTicker(self: IBClient, tickerId: TickerID): Future[Ticker] {.async.} =
    while not (self.tickers[tickerID].receiving):
        await sleepAsync(5)
    result = self.tickers[tickerId]

proc sendMessage(self: IBClient, msg: string) {.async.} =
    asyncCheck self.socket.send(newMessage(msg))

proc sendRequestWithReqId[T](self: IBClient, msg: string, reqID: int): Future[seq[T]] {.async.} =
    asyncCheck self.sendMessage(msg)
    result = await retrieve[T](self, reqID)

proc sendOrder(self: IBClient, msg: string, orderID: OrderID): Future[OrderTracker] {.async.} =
    asyncCheck self.sendMessage(msg)
    result = await retrieveOrder(self,orderID)

proc sendTicker(self: IBClient, msg: string, tickerID: TickerID, contract: Contract): Future[Ticker] {.async.} =
    self.tickers[tickerID] = newTicker()
    self.tickers[tickerID].contract = contract # attach contract
    asyncCheck self.sendMessage(msg)
    result = await retrieveTicker(self,tickerID)
    
    
# unexposed requests

proc reqCurrentTime(self: IBClient) {.async.} =
    var msg = <>(REQ_CURRENT_TIME) & <>(1)
    waitFor self.sendMessage(msg)

proc reqNextOrderID(self: IBClient): Future[OrderID] {.async.} =
    self.nextOrderID = -1
    var msg = <>(REQ_IDS) & <>(1) & <>(1)
    waitFor self.sendMessage(msg)
    while self.nextOrderID == -1:
        await sleepAsync(5)
    result = self.nextOrderID
    
proc reqAcctUpdate(self: IBClient, subscribe: bool) {.async.} =
    self.account.updated = false
    var msg = <>(REQ_ACCT_DATA) & <>(2) & <>(subscribe) & <>("")
    waitFor self.sendMessage(msg)

proc newIBClient*(): IBClient =
    new(result)
    result.socket = newAsyncSocket()
    result.conState = csDisconnected
    result.optionalCapabilities = ""
    result.logger = newFileStream("log.txt", fmWrite)
    result.account = newAccount()
    result.nextReqID = 0
    result.nextOrderID = -1
    result.nextTickerID = 0

proc startAPI(self: IBClient) {.async.} =
    var msg = <>(START_API) & <>(2) & <>(self.clientID)
    if self.serverVersion >= MIN_SERVER_VER_OPTIONAL_CAPABILITIES:
        msg &= <>(self.optionalCapabilities)
    asyncCheck self.sendMessage(msg)

proc listen(self: IBClient): Future[void] {.async.} =
    while self.conState == csConnected:
        let (messageCode, fields) = await self.readMessage()
        self.logger.writeLine($Incoming(messageCode) & $fields)
        case Incoming(messageCode) # handle non-request messages directly
        of Incoming.MANAGED_ACCTS:
            self.handleManagedAcctsMsg(fields)
        of Incoming.CURRENT_TIME:
            self.handleCurrentTimeMsg(fields)
        of Incoming.NEXT_VALID_ID:
            self.handleNextOrderIdMsg(fields)
        of Incoming.ACCT_VALUE:
            self.handleAcctValueUpdateMsg(fields)
        of Incoming.ACCT_DOWNLOAD_END:
            self.handleAcctUpdateEndMsg(fields)
        of Incoming.ACCT_UPDATE_TIME:
            self.handleAcctUpdateTimeMsg(fields)
        of Incoming.PORTFOLIO_VALUE:
            self.handlePortfolioValueMsg(fields)
        of Incoming.CONTRACT_DATA: # responses to requests
            let thisReqID = parseInt(fields[1])
            for reqID in self.requests[messageCode]:
                if reqID == thisReqID:
                    if self.responses[reqID].isNil:
                        self.responses[reqID] = Response(reqId: thisReqID, mssgCode: messageCode, payload: @[fields], ready: false)
                    else:
                        self.responses[reqID].payload.add(fields)
        of Incoming.CONTRACT_DATA_END:
            let thisReqId = parseInt(fields[1])
            for reqId in self.requests[ord(Incoming.CONTRACT_DATA)]:
                if reqId == thisReqId:
                    self.responses[reqID].ready = true
        of Incoming.HISTORICAL_DATA:
            let thisReqID = parseInt(fields[0])
            for reqID in self.requests[messageCode]:
                if reqID == thisReqID:
                        self.responses[reqID] = Response(reqId: thisReqID, mssgCode: messageCode, payload: @[fields], ready: true)
        of Incoming.OPEN_ORDER:
            self.handleOpenOrderUpdateMsg(fields)
        of Incoming.ORDER_STATUS:
            self.handleOrderStatusUpdateMsg(fields)
        of Incoming.COMMISSION_REPORT:
            self.handleCommissionReportMsg(fields)
        of Incoming.EXECUTION_DATA:
            self.handleExecutionDataMsg(fields)
        of Incoming.TICK_PRICE, Incoming.TICK_SIZE, Incoming.TICK_STRING, Incoming.TICK_GENERIC:
            let thisTickerID = parseInt(fields[1])
            if not(self.tickers.hasKey(thisTickerID)):
                return
            self.tickers[thisTickerID].receiving = true
            self.handleTickMsg(fields,thisTickerId,Incoming(messageCode))

        else:
            discard
            # self.requests[messageCode] = @[] #delete served requests
        
proc keepAlive(self: IBClient): Future[void] {.async.} =
    while self.conState == csConnected:
        await self.reqCurrentTime()
        await sleepAsync(1000)

proc connect*(self: IBClient, host: string , port: int, clientID: int) {.async.} =
    if self.conState == csConnected:
        return
    self.clientID = clientID
    waitFor self.socket.connect(host, Port(port))
    # initial handshake
    waitFor self.socket.send(API_SIGN)
    var msg = "v" & $MIN_CLIENT_VER & ".." & $MAX_CLIENT_VER
    waitFor self.socket.send(newMessage(msg))
    self.conState = csConnecting
    var (serverVersion, connectTime) = waitFor self.readMessage()
    self.serverVersion = serverVersion
    self.conState = csConnected
    waitFor self.startAPI()
    self.listenerTask = self.listen()
    self.keepAliveTask = self.keepAlive()
    waitFor self.reqAcctUpdate(true)

proc disconnect*(self: IBClient) =
    self.clientID = -1
    self.socket.close()
    self.conState = csDisconnected
    self.serverVersion = 0
    self.socket = newAsyncSocket() #existing socket cannot be reconnected


## requests

proc reqContractDetails*(self: IBClient, contract: Contract): Future[seq[ContractDetails]] {.async.} =
    inc(self.nextReqId)
    var msg = <>(REQ_CONTRACT_DATA) & <>(8) & <>(self.nextReqID) & <>(contract.conId)
    msg &= <>(contract.symbol) & <>($contract.secType) & <>(contract.lastTradeDateOrContractMonth)
    msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
    msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(contract.currency)
    msg &= <>(contract.localSymbol) & <>(contract.tradingClass) & <>(contract.includeExpired)
    msg &= <>(contract.secIdType) & <>(contract.secId)
    self.registerReq(self.nextReqId, ord(Incoming.CONTRACT_DATA))
    result = await sendRequestWithReqId[ContractDetails](self, msg, self.nextReqId)

proc reqHistoricalData*(self: IBClient, contract: Contract, endDateTime: DateTime, duration: string,
        barPeriod: string, whatToShow: string, useRTH: bool): Future[BarSeries] {.async.} =
    inc(self.nextReqId)
    var msg = <>(REQ_HISTORICAL_DATA) & <>(self.nextReqId) & <>(contract.conId)
    msg &= <>(contract.symbol) & <>($contract.secType) & <>(contract.lastTradeDateOrContractMonth)
    msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
    msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(contract.currency)
    msg &= <>(contract.localSymbol) & <>(contract.tradingClass) & <>(contract.includeExpired) 
    msg &= <>(endDateTime.format("yyyyMMdd HH:mm:ss") & " UTC") & <>(barPeriod) & <>(duration) & <>(useRTH) & <>(whatToShow) & <>(1)
    msg &= <>(false) & <>("")
    self.registerReq(self.nextReqId, ord(Incoming.HISTORICAL_DATA))
    result = (await sendRequestWithReqId[BarSeries](self, msg, self.nextReqId))[0]

proc reqHistoricalData*(self: IBClient, contract: Contract, duration: string, barPeriod: string,
        whatToShow: string, useRTH: bool): Future[BarSeries] {.async.} =
    inc(self.nextReqId)
    var msg = <>(REQ_HISTORICAL_DATA) & <>(self.nextReqId) & <>(contract.conId)
    msg &= <>(contract.symbol) & <>($contract.secType) & <>(contract.lastTradeDateOrContractMonth)
    msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
    msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(contract.currency)
    msg &= <>(contract.localSymbol) & <>(contract.tradingClass) & <>(contract.includeExpired) 
    msg &= <>("") & <>(barPeriod) & <>(duration) & <>(useRTH) & <>(whatToShow) & <>(1)
    msg &= <>(false) & <>("")
    self.registerReq(self.nextReqId, ord(Incoming.HISTORICAL_DATA))
    result = (await sendRequestWithReqId[BarSeries](self, msg, self.nextReqId))[0]

proc placeOrder*(self: IBClient, contract: Contract, order: Order): Future[OrderTracker] {.async.} =
    let orderID = await self.reqNextOrderID()
    var msg = <>(PLACE_ORDER) & <>(orderID)
    # contract fields
    msg &= <>(contract.conId)
    msg &= <>(contract.symbol) & <>($contract.secType) & <>(contract.lastTradeDateOrContractMonth)
    msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
    msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(contract.currency)
    msg &= <>(contract.localSymbol) & <>(contract.tradingClass)
    msg &= <>(contract.secIdType) & <>(contract.secId)
    # main order fields
    msg &= <>(order.action) & <>(order.totalQuantity) & <>(order.orderType) & <>(order.lmtPrice)
    msg &= <>(order.auxPrice)
    # extended order fields
    msg &= <>(order.tif) & <>(order.ocaGroup) & <>(order.account) & <>(order.openClose)
    msg &= <>(order.origin) & <>(order.orderRef) & <>(order.transmit) & <>(order.parentId)
    msg &= <>(order.blockOrder) & <>(order.sweepToFill) & <>(order.displaySize) & <>(order.triggerMethod)
    msg &= <>(order.outsideRth) & <>(order.hidden)
    # no support for BAG orders!
    msg &= <>("") # deprecated sharesAllocation field
    msg &= <>(order.discretionaryAmt) & <>(order.goodAfterTime) & <>(order.goodTillDate)
    msg &= <>(order.faGroup) & <>(order.faMethod) & <>(order.faPercentage) & <>(order.faProfile)
    msg &= <>(order.modelCode) & <>(order.shortSaleSlot) & <>(order.designatedLocation)
    msg &= <>(order.exemptCode) & <>(order.ocaType) & <>(order.rule80A) & <>(order.settlingFirm)
    msg &= <>(order.allOrNone) & <>(order.minQty) & <>(order.percentOffset) & <>(order.eTradeOnly)
    msg &= <>(order.firmQuoteOnly) & <>(order.nbboPriceCap) & <>(order.auctionStrategy)
    msg &= <>(order.startingPrice) & <>(order.stockRefPrice) & <>(order.delta)
    msg &= <>(order.stockRangeLower) & <>(order.stockRangeUpper)
    msg &= <>(order.overridePercentageConstraints) & <>(order.volatility) & <>(order.volatilityType)
    msg &= <>(order.deltaNeutralOrderType) & <>(order.deltaNeutralAuxPrice)
    if order.deltaNeutralOrderType != OrderType.Unset:
        msg &= <>(order.deltaNeutralConId) & <>(order.deltaNeutralSettlingFirm)
        msg &= <>(order.deltaNeutralClearingAccount) & (order.deltaNeutralClearingIntent)
        msg &= <>(order.deltaNeutralOpenClose) & <>(order.deltaNeutralShortSale)
        msg &= <>(order.deltaNeutralShortSaleSlot) & <>(order.deltaNeutralDesignatedLocation)
    msg &= <>(order.continuousUpdate) & <>(order.referencePriceType)
    msg &= <>(order.trailStopPrice) & <>(order.trailingPercent)
    msg &= <>(order.scaleInitLevelSize) & <>(order.scaleSubsLevelSize)
    msg &= <>(order.scalePriceIncrement)
    if order.scalePriceIncrement > 0 and order.scalePriceIncrement != UNSET_FLOAT:
        msg &= <>(order.scalePriceAdjustValue) & <>(order.scalePriceAdjustInterval)
        msg &= <>(order.scaleProfitOffset) & <>(order.scaleAutoReset)
        msg &= <>(order.scaleInitPosition) & <>(order.scaleInitFillQty)
        msg &= <>(order.scaleRandomPercent)
    msg &= <>(order.scaleTable) & <>(order.activeStartTime) & <>(order.activeStopTime)
    msg &= <>(order.hedgeType)
    if order.hedgeType != HedgeType.Unset:
        msg &= <>(order.hedgeParam)
    msg &= <>(order.optOutSmartRouting) & <>(order.clearingAccount) & <>(order.clearingIntent)
    msg &= <>(order.notHeld)
    msg &= <>(false) # no support for deltaNeutralContract for now!
    msg &= <>("") # no support for algo orders for now!
    msg &= <>("") # algoId not supported for now
    msg &= <>(order.whatIf)
    msg &= <>("") # no support for miscOptions for now!
    msg &= <>(order.solicited)
    msg &= <>(order.randomizeSize) & <>(order.randomizePrice)
    #PEG BENCH orders not supported!
    msg &= <>(0) #order conditions not supported!
    msg &= <>(order.adjustedOrderType) & <>(order.triggerPrice) & <>(order.lmtPriceOffset)
    msg &= <>(order.adjustedStopPrice) & <>(order.adjustedStopLimitPrice) & <>(order.adjustedTrailingAmount)
    msg &= <>(order.adjustableTrailingUnit) & <>(order.extOperator)
    msg &= <>("") & <>("") # soft dollar tier not supported yet!
    msg &= <>(order.cashQty) & <>(order.mifid2DecisionMaker) & <>(order.mifid2DecisionAlgo)
    msg &= <>(order.mifid2ExecutionTrader) & <>(order.mifid2ExecutionAlgo)
    msg &= <>(order.dontUseAutoPriceForHedge) & <>(order.isOmsContainer)
    msg &= <>(order.discretionaryUpToLimitPrice) & <>(order.usePriceMgmtAlgo)
    echo msg
    self.orders[orderID] = await self.sendOrder(msg, orderID) #store orders in client
    return self.orders[orderID] # return handle to the OrderTracker

proc reqMktData*(self: IBClient, contract: Contract, snapshot: bool, regulatory: bool = false, additionalData:seq[GenericTickType] = @[],
        callback: proc(ticker: Ticker) {.async.} = nil): Future[Ticker] {.async.} =
    inc self.nextTickerID
    var genericTicks = ""
    for tickType in additionalData:
        addSep(genericTicks,",")
        add(genericTicks,$tickType)
    var msg = <>(REQ_MKT_DATA) & <>(11) & <>(self.nextTickerID)
    msg &= <>(contract.conId)
    msg &= <>(contract.symbol) & <>($contract.secType) & <>(contract.lastTradeDateOrContractMonth)
    msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
    msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(contract.currency)
    msg &= <>(contract.localSymbol) & <>(contract.tradingClass)
    msg &= <>(false) & <>(genericTicks) & <>(snapshot) & <>(regulatory)
    msg &= <>("") #options
    if not(isNil(callback)):
        self.tickerUpdateHandlers[self.nextTickerID] = callback
    return await self.sendTicker(msg, self.nextTickerID, contract)


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







