import streams
import strutils
import ibEnums, ibContractTypes
import macros

type
  FieldStream* = ref object
    data: seq[string]
    cursor: int

proc newFieldStream*(data: seq[string]): FieldStream =
  new(result)
  result.data = data
  result.cursor = -1

proc next*(stream: FieldStream): string =
  inc(stream.cursor)
  if stream.cursor < stream.data.len:
    return stream.data[stream.cursor]
  else:
    return ""
proc peek(stream: FieldStream): string =
  return stream.data[stream.cursor+1]

proc skip*(stream: FieldStream) =
  inc(stream.cursor)

proc skip*(stream: FieldStream, by: int) =
  stream.cursor += by

proc encode*[T](val: T): string =
  ## Defines field encodings according to EClient.cpp/EClient.h
  when T is bool:
    if val:
      return "1\0"
    else:
      return "0\0"
  elif T is float:
    if val == UNSET_FLOAT:
      return "\0"
    return formatFloat(val, precision = 10) & "\0"
  elif T is int:
    if val == UNSET_INT:
      return "\0"
    return $val & "\0"
  elif (T is Origin or
        T is TriggerMethod or
        T is ShortSaleSlot or
        T is OptionOpenClose or
        T is OCAType or
        T is VolatilityType or
        T is ReferencePriceType or
        T is AuctionStrategy or
        T is UsePriceMmgtAlgo or
        T is OCAType or
        T is TickType or
        T is MarketDataType):
    if ord(val) == UNSET_INT:
      return "\0"
    return $ord(val) & "\0"
  else:
    return $val & "\0"

proc `<>`*[T](val: T): string {.inline.} =
  return encode[T](val)

proc decode*[T](field: string): T =
  when T is string:
    return field
  elif T is float:
    if field == "":
      return UNSET_FLOAT
    else:
      return parseFloat(field)
  elif T is int:
    if field == "":
      return UNSET_INT
    else:
      return parseInt(field)
  elif T is bool:
    if field == "1":
      return true
    elif field == "0":
      return false
  elif (T is Origin or
        T is TriggerMethod or
        T is ShortSaleSlot or
        T is OptionOpenClose or
        T is AuctionStrategy or
        T is VolatilityType or
        T is ReferencePriceType or
        T is UsePriceMmgtAlgo or
        T is OCAType or
        T is MarketDataType):
    if field == "":
      return T(UNSET_INT)
    return T(parseInt(field))
  elif T is TickType:
    if field == "":
      return TickType.NotSet
    return T(parseInt(field))
  elif T is enum:
    return parseEnum[T](field)

macro stringify(u: typed): untyped =
  var name: string
  if u.kind == nnkDotExpr:
    for (i, child) in u.pairs:
      if i == 1:
        name = strVal(child)
  elif u.kind == nnkCheckedFieldExpr:
    for child in u.children:
      if child.kind == nnkDotExpr:
        for (i, child2) in child.pairs:
          if i == 1:
            name = $child2
  else:
    name = strVal(u)
  result = quote do: echo `name`

template `<<`*(u, fields: typed): untyped =
  when defined(debugParsing):
    stringify(u)
    echo peek(fields)
  u = decode[u](fields.next)


