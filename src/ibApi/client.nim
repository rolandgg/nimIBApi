import asyncnet, asyncfutures, asyncdispatch
import net
import os
import streams, strutils, strformat
import times
import tables, sets, options, results

import utils, message, ibEnums, ibContractTypes, position, ibMarketDataTypes
import ibTickTypes, ibOrderTypes, ibExecutionTypes, ibFundamentalDataTypes
import ibScannerTypes
import orderTracker, handlers, ticker
import account
include apiConstants

type
  IBError* = object of CatchableError
  MssgCode = int
  ReqID = int
  TickerID = int
  Portfolio = Table[int, Position]
  Response = object
    reqID: ReqID
    mssgCode: MssgCode
    ready: bool
    payload: seq[seq[string]]
  IBResult[T] = Result[T, ref IBError]
  ConnectionState = enum
    csConnecting, csConnected, csDisconnected
  IBClient* = ref object
    logger: FileStream
    socket: AsyncSocket
    conState: ConnectionState
    marketDataSetting: MarketDataType
    conTime: Time
    serverTime: Time
    serverVersion*: int
    clientID*: int
    optionalCapabilities*: string
    accountList: seq[string]
    account*: Account
    portfolio*: Portfolio
    requests: Table[MssgCode, HashSet[int]]
    responses: Table[int, Option[IBResult[Response]]]
    orders: Table[OrderID, OrderTracker]
    tickers: Table[TickerID, Ticker]
    tickerUpdateHandlers: Table[TickerID, proc(ticker: Ticker) {.async.}]
    orderUpdateHandlers: Table[OrderID, proc(order: OrderTracker)]
    accountUpdateHandler: proc(account: Account)
    positionUpdateHandler: proc(portfolio: Portfolio)
    nextReqID: ReqID
    nextOrderID: OrderID
    nextTickerID: TickerID

proc marketDataSetting*(self: IBClient): MarketDataType =
  self.marketDataSetting

proc isConnected*(self: IBClient): bool =
  if self.conState == csConnected:
    return true
  else:
    return false

proc disconnect*(self: IBClient) =
  self.clientID = -1
  self.conState = csDisconnected
  self.socket.close()
  self.serverVersion = 0
  self.socket = newAsyncSocket() #existing socket cannot be reconnected
  self.nextReqID = 0
  self.nextOrderID = -1
  self.nextTickerID = 0
  self.marketDataSetting = MarketDataType.RealTime
  self.requests.clear()
  self.responses.clear()
  self.orders.clear()
  self.tickers.clear()
  self.tickerUpdateHandlers.clear()
  self.orderUpdateHandlers.clear()

## Handlers

# Handlers for messages for which no requests are exposed

proc handleManagedAcctsMsg(self: IBClient, payload: seq[string]) {.inline.} =
  self.accountList = payload[1].split(",")

proc handleCurrentTimeMsg(self: IBClient, payload: seq[string]) {.inline.} =
  self.serverTime = fromUnix(parseInt(payload[1]))
  when not defined(release):
    echo "Heartbeat at " & $self.serverTime

proc handleNextOrderIdMsg(self: IBClient, payload: seq[string]) {.inline.} =
  self.nextOrderID = parseInt(payload[1])

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
  for orderId, order in self.orders.pairs: # this is potentially dangerous! assuming that execution data will always arrive before the commission report!
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
  var tracker = handle[OrderTracker](payload)
  let orderId = tracker.order.orderId
  if self.orders.hasKey(orderId):
    self.orders[orderId].contract = tracker.contract
    self.orders[orderId].order = tracker.order
    self.orders[orderId].orderState = tracker.orderState
  else:
    self.orders[orderId] = tracker

proc handleTickMsg(self: IBClient, payload: seq[string], id: TickerID,
        msgCode: Incoming) =
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

proc handleMarketDataTypeMsg(self: IBClient, payload: seq[string]) =
  var fields = newFieldStream(payload)
  fields.skip
  var reqId: TickerID
  reqID << fields
  self.marketDataSetting << fields
  if self.tickers.hasKey(reqID):
    self.tickers[reqId].marketDataSetting = self.marketDataSetting

proc handleResponse(self: IBClient, thisReqID: int, mssgCode: int, payload: seq[string]) =
  if thisReqID < 0: #if no reqID for this request, serve all pending requests the same response
    for reqID in self.requests[mssgCode]:
      self.responses[reqID] = some(IBResult[Response].ok Response(
              reqID: thisReqID, mssgCode: mssgCode, payload: @[payload], ready: true))
    self.requests[mssgCode].clear()
  else:
    if thisReqID in self.requests[mssgCode]:
      self.responses[thisReqID] = some(IBResult[Response].ok Response(
              reqID: thisReqID, mssgCode: mssgCode, payload: @[payload], ready: true))
      self.requests[mssgCode].excl(thisReqID)

proc handleErrorMessage(self: IBClient, payload: seq[string]) =
  var fields = newFieldStream(payload)
  fields.skip
  var reqId: int
  var errorCode: int
  var errorMsg: string
  reqID << fields
  errorCode << fields
  errorMsg << fields
  # error codes that are no errors (mostly related to market data subscriptions):
  # - 492: warning for lacking subscriptions with scanner requests
  const ignoreList = [492]

  if reqID > -1 and not(errorCode in ignoreList):
    for mssgCode, reqIDs in self.requests.mpairs:
      reqIDs.excl(reqID)
    if self.responses.hasKey(reqID):
      self.responses[reqID] = some(IBResult[Response].err (
              newException(IBError, fmt"Error code: {errorCode} - {errorMsg}")))
    if self.tickers.hasKey((reqID)):
      self.tickers[reqId].error = some((code: errorCode, msg: errorMsg))
    if self.orders.hasKey((reqID)):
      self.orders[reqId].error = some((code: errorCode, msg: errorMsg))

  when not defined(release):
    echo "INFO: " & errorMsg

proc registerReq(self: IBClient, incoming: Incoming) =
  ## adds the request both to the pending requests and pending responses tables
  let mssgCode = ord(incoming)
  if not(self.requests.hasKey(mssgCode)):
    self.requests[mssgCode] = initHashSet[int]()
  self.requests[mssgCode].incl(self.nextReqID)
  self.responses[self.nextReqID] = none(Result[Response, ref IBError])

proc readMessage(self: IBClient): Future[tuple[id: int, payload: seq[
        string]]] {.async.} =

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

proc retrieveMulti[T](self: IBClient, reqId: int): Future[IBResult[seq[T]]] {.async.} =
  while self.responses.hasKey(reqId):
    if self.responses[reqID].isSome:
      break
    poll()
  if not(self.responses.hasKey(reqId)):
    return IBResult[seq[T]].err (newException(IBError, "No data returned"))
  while true:
    let resp = self.responses[reqID].get()
    if resp.isErr:
      result = IBResult[seq[T]].err resp.error
      self.responses.del(reqId)
      return
    if resp.get().ready:
      let unwrap = resp.get()
      var res: seq[T] = @[]
      for line in unwrap.payload:
        res.add(handle[T](line))
      result = IBResult[seq[T]].ok res
      self.responses.del(reqId)
      return
    poll()

proc retrieve[T](self: IBClient, reqId: int): Future[IBResult[T]] {.async.} =
  while self.responses.hasKey(reqId):
    if self.responses[reqID].isSome:
      break
    poll()
  if not(self.responses.hasKey(reqId)):
    return IBResult[T].err (newException(IBError, "No data returned"))
  let resp = self.responses[reqID].get()
  if resp.isErr:
    result = IBResult[T].err resp.error
  else:
    result = IBResult[T].ok handle[T](resp.get().payload[0])
  self.responses.del(reqId)

proc retrieveOrder(self: IBClient, orderId: int): Future[OrderTracker] {.async.} =
  while not (self.orders.hasKey(orderId)):
    poll()
  result = self.orders[orderId]

proc retrieveTicker(self: IBClient, tickerId: TickerID): Future[Ticker] {.async.} =
  while not (self.tickers[tickerID].receiving):
    poll()
  result = self.tickers[tickerId]

proc sendMessage(self: IBClient, msg: string) {.async.} =
  asyncCheck self.socket.send(newMessage(msg))

proc sendRequestWithReqIdMulti[T](self: IBClient, msg: string): Future[IBResult[
        seq[T]]] {.async.} =
  asyncCheck self.sendMessage(msg)
  inc self.nextReqID
  result = await retrieveMulti[T](self, self.nextReqID-1)

proc sendRequestWithReqId[T](self: IBClient, msg: string): Future[IBResult[
        T]] {.async.} =
  asyncCheck self.sendMessage(msg)
  inc self.nextReqID
  result = await retrieve[T](self, self.nextReqID-1)

proc sendOrder(self: IBClient, msg: string, orderID: OrderID): Future[
        OrderTracker] {.async.} =
  asyncCheck self.sendMessage(msg)
  result = await retrieveOrder(self, orderID)

proc sendTicker(self: IBClient, msg: string, tickerID: TickerID,
        contract: Contract): Future[Ticker] {.async.} =
  self.tickers[tickerID] = newTicker()
  self.tickers[tickerID].contract = contract # attach contract
  asyncCheck self.sendMessage(msg)
  result = await retrieveTicker(self, tickerID)

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

proc reqCancelScannerSubscription(self: IBClient, reqID: int) {.async.} =
  var msg = newStringStream("")
  msg << CANCEL_SCANNER_SUBSCRIPTION << 1 << reqID
  asyncCheck self.sendMessage(msg.toString())

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
  result.marketDataSetting = MarketDataType.RealTime

proc startAPI(self: IBClient) {.async.} =
  var msg = <>(START_API) & <>(2) & <>(self.clientID)
  if self.serverVersion >= MIN_SERVER_VER_OPTIONAL_CAPABILITIES:
    msg &= <>(self.optionalCapabilities)
  asyncCheck self.sendMessage(msg)

proc listen(self: IBClient): Future[void] {.async.} =
  while self.conState == csConnected:
    var messageCode: int
    var fields: seq[string]
    try:
      (messageCode, fields) = await self.readMessage()
    except OSError:
      return
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
          if self.responses[reqID].isNone:
            self.responses[reqID] = some(IBResult[
                    Response].ok Response(reqId: thisReqID,
                    mssgCode: messageCode, payload: @[fields], ready: false))
          else:
            self.responses[reqID].get().get().payload.add(fields)
    of Incoming.CONTRACT_DATA_END:
      let thisReqId = parseInt(fields[1])
      for reqId in self.requests[ord(Incoming.CONTRACT_DATA)]:
        if reqId == thisReqId:
          self.responses[reqID].get().get().ready = true
    of Incoming.OPEN_ORDER:
      self.handleOpenOrderUpdateMsg(fields)
    of Incoming.ORDER_STATUS:
      self.handleOrderStatusUpdateMsg(fields)
    of Incoming.COMMISSION_REPORT:
      self.handleCommissionReportMsg(fields)
    of Incoming.EXECUTION_DATA:
      self.handleExecutionDataMsg(fields)
    of Incoming.TICK_PRICE, Incoming.TICK_SIZE, Incoming.TICK_STRING,
            Incoming.TICK_GENERIC:
      let thisTickerID = parseInt(fields[1])
      if not(self.tickers.hasKey(thisTickerID)):
        return
      self.tickers[thisTickerID].receiving = true
      self.handleTickMsg(fields, thisTickerId, Incoming(messageCode))
    of Incoming.MARKET_DATA_TYPE:
      self.handleMarketDataTypeMsg(fields)
    of Incoming.FUNDAMENTAL_DATA, 
       Incoming.SCANNER_DATA:
      let thisReqID = parseInt(fields[1])
      self.handleResponse(thisReqID, messageCode, fields)
    of Incoming.SYMBOL_SAMPLES,
       Incoming.HISTORICAL_DATA:
      let thisReqID = parseInt(fields[0])
      self.handleResponse(thisReqID, messageCode, fields)
    of Incoming.SCANNER_PARAMETERS:
      let thisReqID = -1 #no reqID transmitted for this request
      self.handleResponse(thisReqID, messageCode, fields)
    of Incoming.ERR_MSG:
      self.handleErrorMessage(fields)
    else:
      discard
      # self.requests[messageCode] = @[] #delete served requests

proc keepAlive(self: IBClient): Future[void] {.async.} =
  while self.conState == csConnected:
    await self.reqCurrentTime()
    await sleepAsync(1000)

proc connect*(self: IBClient, host: string, port: int, clientID: int) {.async.} =
  if self.conState == csConnected:
    return
  self.clientID = clientID
  await self.socket.connect(host, Port(port))
  # initial handshake
  await self.socket.send(API_SIGN)
  var msg = "v" & $MIN_CLIENT_VER & ".." & $MAX_CLIENT_VER
  await self.socket.send(newMessage(msg))
  self.conState = csConnecting
  var (serverVersion, _) = await self.readMessage()
  self.serverVersion = serverVersion
  self.conState = csConnected
  await self.startAPI()
  asyncCheck self.listen()
  asyncCheck self.keepAlive()
  await self.reqAcctUpdate(true)

## requests

proc reqContractDetails*(self: IBClient, contract: Contract): Future[seq[
        ContractDetails]] {.async.} =
  var msg = <>(REQ_CONTRACT_DATA) & <>(8) & <>(self.nextReqID) & <>(contract.conId)
  msg &= <>(contract.symbol) & <>($contract.secType) & <>(
          contract.lastTradeDateOrContractMonth)
  msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
  msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(
          contract.currency)
  msg &= <>(contract.localSymbol) & <>(contract.tradingClass) & <>(
          contract.includeExpired)
  msg &= <>(contract.secIdType) & <>(contract.secId)
  self.registerReq(Incoming.CONTRACT_DATA)
  let resp = await sendRequestWithReqIdMulti[ContractDetails](self, msg)
  result = resp.tryGet()

proc reqHistoricalData*(self: IBClient, contract: Contract,
        endDateTime: DateTime, duration: string, barPeriod: string,
        whatToShow: string, useRTH: bool): Future[BarSeries] {.async.} =
  var msg = <>(REQ_HISTORICAL_DATA) & <>(self.nextReqId) & <>(contract.conId)
  msg &= <>(contract.symbol) & <>($contract.secType) & <>(
          contract.lastTradeDateOrContractMonth)
  msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
  msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(
          contract.currency)
  msg &= <>(contract.localSymbol) & <>(contract.tradingClass) & <>(
          contract.includeExpired)
  msg &= <>(endDateTime.format("yyyyMMdd HH:mm:ss") & " UTC") & <>(
          barPeriod) & <>(duration) & <>(useRTH) & <>(whatToShow) & <>(1)
  msg &= <>(false) & <>("")
  self.registerReq(Incoming.HISTORICAL_DATA)
  let resp = await sendRequestWithReqId[BarSeries](self, msg)
  result = resp.tryGet()

proc reqHistoricalData*(self: IBClient, contract: Contract, duration: string,
        barPeriod: string, whatToShow: string,
        useRTH: bool): Future[BarSeries] {.async.} =
  inc(self.nextReqId)
  var msg = <>(REQ_HISTORICAL_DATA) & <>(self.nextReqId) & <>(contract.conId)
  msg &= <>(contract.symbol) & <>($contract.secType) & <>(
          contract.lastTradeDateOrContractMonth)
  msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
  msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(
          contract.currency)
  msg &= <>(contract.localSymbol) & <>(contract.tradingClass) & <>(
          contract.includeExpired)
  msg &= <>("") & <>(barPeriod) & <>(duration) & <>(useRTH) & <>(whatToShow) &
          <>(1)
  msg &= <>(false) & <>("")
  self.registerReq(Incoming.HISTORICAL_DATA)
  let resp = await sendRequestWithReqId[BarSeries](self, msg)
  result = resp.tryGet()

proc placeOrder*(self: IBClient, contract: Contract,
  order: Order): Future[OrderTracker] {.async.} =
  let orderID = await self.reqNextOrderID()
  var msg = <>(PLACE_ORDER) & <>(orderID)
  # contract fields
  msg &= <>(contract.conId)
  msg &= <>(contract.symbol) & <>($contract.secType) & <>(
          contract.lastTradeDateOrContractMonth)
  msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
  msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(
          contract.currency)
  msg &= <>(contract.localSymbol) & <>(contract.tradingClass)
  msg &= <>(contract.secIdType) & <>(contract.secId)
  # main order fields
  msg &= <>(order.action) & <>(order.totalQuantity) & <>(order.orderType) &
          <>(order.lmtPrice)
  msg &= <>(order.auxPrice)
  # extended order fields
  msg &= <>(order.tif) & <>(order.ocaGroup) & <>(order.account) & <>(
          order.openClose)
  msg &= <>(order.origin) & <>(order.orderRef) & <>(order.transmit) & <>(order.parentId)
  msg &= <>(order.blockOrder) & <>(order.sweepToFill) & <>(
          order.displaySize) & <>(order.triggerMethod)
  msg &= <>(order.outsideRth) & <>(order.hidden)
  # no support for BAG orders!
  msg &= <>("") # deprecated sharesAllocation field
  msg &= <>(order.discretionaryAmt) & <>(order.goodAfterTime) & <>(
          order.goodTillDate)
  msg &= <>(order.faGroup) & <>(order.faMethod) & <>(order.faPercentage) & <>(
          order.faProfile)
  msg &= <>(order.modelCode) & <>(order.shortSaleSlot) & <>(
          order.designatedLocation)
  msg &= <>(order.exemptCode) & <>(order.ocaType) & <>(order.rule80A) & <>(
          order.settlingFirm)
  msg &= <>(order.allOrNone) & <>(order.minQty) & <>(order.percentOffset) &
          <>(order.eTradeOnly)
  msg &= <>(order.firmQuoteOnly) & <>(order.nbboPriceCap) & <>(
          order.auctionStrategy)
  msg &= <>(order.startingPrice) & <>(order.stockRefPrice) & <>(order.delta)
  msg &= <>(order.stockRangeLower) & <>(order.stockRangeUpper)
  msg &= <>(order.overridePercentageConstraints) & <>(order.volatility) & <>(
          order.volatilityType)
  msg &= <>(order.deltaNeutralOrderType) & <>(order.deltaNeutralAuxPrice)
  if order.deltaNeutralOrderType != OrderType.Unset:
    msg &= <>(order.deltaNeutralConId) & <>(order.deltaNeutralSettlingFirm)
    msg &= <>(order.deltaNeutralClearingAccount) & (
            order.deltaNeutralClearingIntent)
    msg &= <>(order.deltaNeutralOpenClose) & <>(order.deltaNeutralShortSale)
    msg &= <>(order.deltaNeutralShortSaleSlot) & <>(
            order.deltaNeutralDesignatedLocation)
  msg &= <>(order.continuousUpdate) & <>(order.referencePriceType)
  msg &= <>(order.trailStopPrice) & <>(order.trailingPercent)
  msg &= <>(order.scaleInitLevelSize) & <>(order.scaleSubsLevelSize)
  msg &= <>(order.scalePriceIncrement)
  if order.scalePriceIncrement > 0 and order.scalePriceIncrement != UNSET_FLOAT:
    msg &= <>(order.scalePriceAdjustValue) & <>(
            order.scalePriceAdjustInterval)
    msg &= <>(order.scaleProfitOffset) & <>(order.scaleAutoReset)
    msg &= <>(order.scaleInitPosition) & <>(order.scaleInitFillQty)
    msg &= <>(order.scaleRandomPercent)
  msg &= <>(order.scaleTable) & <>(order.activeStartTime) & <>(
          order.activeStopTime)
  msg &= <>(order.hedgeType)
  if order.hedgeType != HedgeType.Unset:
    msg &= <>(order.hedgeParam)
  msg &= <>(order.optOutSmartRouting) & <>(order.clearingAccount) & <>(
          order.clearingIntent)
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
  msg &= <>(order.adjustedOrderType) & <>(order.triggerPrice) & <>(
          order.lmtPriceOffset)
  msg &= <>(order.adjustedStopPrice) & <>(order.adjustedStopLimitPrice) & <>(
          order.adjustedTrailingAmount)
  msg &= <>(order.adjustableTrailingUnit) & <>(order.extOperator)
  msg &= <>("") & <>("") # soft dollar tier not supported yet!
  msg &= <>(order.cashQty) & <>(order.mifid2DecisionMaker) & <>(
          order.mifid2DecisionAlgo)
  msg &= <>(order.mifid2ExecutionTrader) & <>(order.mifid2ExecutionAlgo)
  msg &= <>(order.dontUseAutoPriceForHedge) & <>(order.isOmsContainer)
  msg &= <>(order.discretionaryUpToLimitPrice) & <>(order.usePriceMgmtAlgo)
  self.orders[orderID] = await self.sendOrder(msg, orderID) #store orders in client
  return self.orders[orderID] # return handle to the OrderTracker

proc reqMktData*(self: IBClient, contract: Contract, snapshot: bool,
    regulatory: bool = false, additionalData: seq[GenericTickType] = @[],
    callback: proc(ticker: Ticker) {.async.} = nil): Future[Ticker] {.async.} =
  inc self.nextTickerID
  var genericTicks = ""
  for tickType in additionalData:
    addSep(genericTicks, ",")
    add(genericTicks, $tickType)
  var msg = <>(REQ_MKT_DATA) & <>(11) & <>(self.nextTickerID)
  msg &= <>(contract.conId)
  msg &= <>(contract.symbol) & <>($contract.secType) & <>(
          contract.lastTradeDateOrContractMonth)
  msg &= <>(contract.strike) & <>(contract.right) & <>(contract.multiplier)
  msg &= <>(contract.exchange) & <>(contract.primaryExchange) & <>(
          contract.currency)
  msg &= <>(contract.localSymbol) & <>(contract.tradingClass)
  msg &= <>(false) & <>(genericTicks) & <>(snapshot) & <>(regulatory)
  msg &= <>("") #options
  if not(isNil(callback)):
    self.tickerUpdateHandlers[self.nextTickerID] = callback
  return await self.sendTicker(msg, self.nextTickerID, contract)

proc reqMarketDataType*(self: IBClient, dataType: MarketDataType) {.async.} =
  if self.marketDataSetting != dataType:
    var msg = <>(REQ_MARKET_DATA_TYPE) & <>(1) & <>(dataType)
    await self.sendMessage(msg)

proc reqFundamentalData*(self: IBClient, contract: Contract,
        kind: FundamentalDataType): Future[FundamentalReport] {.async.} =
  var msg = <>(REQ_FUNDAMENTAL_DATA) & <>(2) & <>(self.nextReqId) & <>(contract.conId)
  msg &= <>(contract.symbol) & <>($contract.secType) & <>(contract.exchange) &
          <>(contract.primaryExchange)
  msg &= <>(contract.currency) & <>(contract.localSymbol)
  msg &= <>(kind)
  msg &= <>("") #tag value list always empty
  self.registerReq(Incoming.FUNDAMENTAL_DATA)
  let resp = await sendRequestWithReqId[FundamentalReport](self, msg)
  result = resp.tryGet()

proc reqMatchingSymbol*(self: IBClient, pattern: string): Future[
        ContractDescriptionList] {.async.} =
  var msg = <>(REQ_MATCHING_SYMBOLS) & <>(self.nextReqId) & <>(pattern)
  self.registerReq(Incoming.SYMBOL_SAMPLES)
  let resp = await sendRequestWithReqId[ContractDescriptionList](self, msg)
  result = resp.tryGet()

proc reqScannerParams*(self: IBClient): Future[ScannerParams] {.async.} =
  var msg = <>(REQ_SCANNER_PARAMETERS) & <>(1)
  self.registerReq(Incoming.SCANNER_PARAMETERS)
  let resp = await sendRequestWithReqId[ScannerParams](self, msg)
  result = resp.tryGet()

proc reqScannerSubscription*(self: IBClient,
  subscription: ScannerSubscription;
  scannerSubscriptionOptions,
  scannerSubscriptionFilterOptions: seq[tuple[tag: string,value: string]] = @[]
  ): Future[ScanDataList] {.async.} =
  var msg = newStringStream("")
  msg << REQ_SCANNER_SUBSCRIPTION << self.nextReqID << subscription.numberOfRows
  msg << subscription.instrument << subscription.locationCode
  msg << subscription.scanCode << subscription.abovePrice << subscription.belowPrice
  msg << subscription.aboveVolume << subscription.marketCapAbove
  msg << subscription.marketCapBelow << subscription.moodyRatingAbove
  msg << subscription.moodyRatingBelow << subscription.spRatingAbove
  msg << subscription.spRatingBelow << subscription.maturityDateAbove
  msg << subscription.maturityDateBelow << subscription.couponRateAbove
  msg << subscription.couponRateBelow << subscription.excludeConvertible
  msg << subscription.averageOptionVolumeAbove << subscription.scannerSettingPairs
  msg << subscription.stockTypeFilter
  #encode scannerSubscriptionOptions
  msg << scannerSubscriptionOptions
  #encode scannerSubscriptionFilterOptions
  msg << scannerSubscriptionFilterOptions
  
  self.registerReq(Incoming.SCANNER_DATA)
  let reqID = self.nextReqID
  let resp = await sendRequestWithReqId[ScanDataList](self, msg.toString())
  asyncCheck self.reqCancelScannerSubscription(reqID)
  result = resp.tryGet()

proc cancel*(self: IBClient, orderTracker: OrderTracker) =
  var msg = newStringStream("")
  msg << CANCEL_ORDER << 1 << orderTracker.order.orderID
  waitFor self.sendMessage(msg.toString())

proc cancel*(self: IBClient, ticker: Ticker) =
  var msg = newStringStream("")
  msg << CANCEL_MKT_DATA << 2 << ticker.id
  waitFor self.sendMessage(msg.toString()) 








