import ibContractTypes

type
    Position* = ref object
        contract*: Contract
        position*, marketPrice*, marketValue*, averageCost*, unrealizedPnL*, realizedPnL*: float
