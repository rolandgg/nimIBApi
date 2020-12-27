import ibEnums, ibContractTypes
import times

type
  Execution* = tuple[
      execId: string,
      time: string,
      acctNumber: string,
      exchange: string,
      side: Side,
      shares: float,
      price: float,
      permId: int,
      clientId: int,
      orderId: int,
      contract: Contract,
      liquidation: int,
      cumQty: float,
      avgPrice: float,
      orderRef: string,
      evRule: string,
      evMultiplier: float,
      modelCode: string,
      lastLiquidity: int,
  ]
  CommissionReport* = tuple[
      execId: string,
      commission: float,
      currency: string,
      realizedPnL: float,
      yieldAmount: float,
      yieldRedemptionDate: int
  ]
  ExecutionFilter* = ref object
    clientId: int
    acctCode: int
    time: Time
    symbol: string
    secType: SecType
    exchange: string
    side: Side


proc newExecutionFilter*(): ExecutionFilter =
  new(result)
  result.time = UNSET_TIME
  result.side = Side.Unset
  result.secType = SecType.Unset

