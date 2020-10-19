import ibContractTypes, ibEnums
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
        marketDataSetting*: MarketDataType

proc newTicker*(): Ticker = 
    new(result)
    result.receiving = false
    result.difficultyToShort = sdUnset
    result.marketDataSetting = MarketDataType.RealTime

proc setShortDifficulty*(ticker: Ticker, x: float) =
    if x > 2.5:
        ticker.difficultyToShort = sdEasy
    elif x > 1.5:
        ticker.difficultyToShort = sdHard
    else:
        ticker.difficultyToShort = sdImpossible
