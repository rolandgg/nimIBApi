import options
import ibOrderTypes, ibContractTypes, ibExecutionTypes

type
    OrderTracker* = ref object
        contract*: Contract
        order*: Order
        error*: Option[tuple[code: int, msg: string]]
        orderState*: OrderState
        orderStatus*: OrderStatus
        executions*: seq[Execution]
        commissionReports*: seq[CommissionReport]

proc newOrderTracker*(contract: Contract, order: Order, orderState: OrderState): OrderTracker =
    new(result)
    result.contract = contract
    result.order = order
    result.orderState = orderState
    result.executions = @[]
    result.commissionReports = @[]

proc isFilled*(order: OrderTracker): bool =
    if order.orderStatus.status == "Filled":
        return true
    else:
        return false

proc commission*(order: OrderTracker): float {.inline.} =
    return order.orderState.commission

proc avgFillPrice*(order: OrderTracker): float {.inline.} =
    return order.orderStatus.avgFillPrice

proc fillTime*(order: OrderTracker): string =
    if not(order.isNil):
        if order.executions.len > 0:
            return order.executions[^1].time
        else:
            return ""
    return ""

proc qtyFilled*(order: OrderTracker): float =
    return order.orderStatus.filled