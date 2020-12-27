import ibEnums, position

type
  AccountSum* = ref object
    accountType*: string
    netLiquidation*: float
    totalCashValue*: float
    settledCash*: float
    accruedCash*: float
    buyingPower*: float
    equityWithLoanValue*: float
    previousEquityWithLoanValue*: float
    grossPositionValue*: float
    reqTEquity*: float
    reqTMargin*: float
    sma*: float
    initMarginReq*: float
    maintMarginReq*: float
    availableFunds*: float
    excessLiquidity*: float
    cushion*: float
    fullInitMarginReq*: float
    fullMaintMarginReq*: float
    fullAvailableFunds*: float
    fullExcessLiquidity*: float
    lookAheadNextChange*: float
    lookAheadInitMarginReq*: float
    lookAheadMaintMarginReq*: float
    lookAheadAvailableFunds*: float
    lookAheadExcessLiquidity*: float
    highestSeverity*: string
    dayTradesRemaining*: int
    leverage*: float

  Account* = ref object
    updated*: bool
    updateTime*: string
    accountCode*: string
    accountType*: string
    cashBalance*: float
    equityWithLoanValue*: float
    excessLiquidity*: float
    netLiquidation*: float
    realizedPnL*: float
    unrealizedPnL*: float
    totalCashBalance*: float
    portfolio*: seq[Position]

proc newAccount*(): Account =
  new(result)
  result.portfolio = @[]




