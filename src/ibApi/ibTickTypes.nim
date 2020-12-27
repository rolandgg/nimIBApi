import ibEnums

type
  TickAttributes* = enum
    taCanAutoExecute, taPastLimit, taPreOpen

  PriceTick* = object
    price*: float
    case kind*: TickType
    of TickType.BID, TickType.ASK, TickType.LAST,
        TickType.DELAYED_BID, TickType.DELAYED_ASK, TickType.DELAYED_LAST:
      size*: int
    else:
      discard
    attributes*: set[TickAttributes]

  SizeTick* = object
    size*: int
    kind*: TickType

  StringTick* = object
    value*: string
    kind*: TickType

  GenericTick* = object
    value*: float
    kind*: TickType





