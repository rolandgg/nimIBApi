import ibContractTypes
type
    ShortDifficulty* = enum
        sdEasy = "Available",sdHard = "Difficult", sdImpossible="Unavailable", sdUnset = ""
    Ticker* = ref object
        contract*: Contract
        bid*,ask*,lastTrade*: float
        bidSize*,askSize*,lastTradeSize*: int
        shortableShares*: int
        difficultyToShort*: ShortDifficulty
        receiving*: bool

proc newTicker*(): Ticker = 
    new(result)
    result.receiving = false
    result.difficultyToShort = sdUnset

proc setShortDifficulty*(ticker: Ticker, x: float) =
    if x > 2.5:
        ticker.difficultyToShort = sdEasy
    elif x > 1.5:
        ticker.difficultyToShort = sdHard
    else:
        ticker.difficultyToShort = sdImpossible
