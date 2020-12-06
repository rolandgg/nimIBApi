import ibEnums, utils
import strutils, times, timezones

type

    ComboLeg = object
        conId: int
        ratio: int
        action: ComboAction
        exchange: string
        openClose: OptionOpenClose
        shortSaleSlot: ShortSaleSlot
        designatedLocation: string
        exemptCode: int


    DeltaNeutralContract = object
        conId: int
        delta: float
        price: float

    Contract* = object
        conId*: int
        symbol*: string
        secType*: SecType
        lastTradeDateOrContractMonth*: string # Options or futures, YYYYMM (FUT) YYYYMMDD (OPT)
        strike*: float
        right*: OptionRight
        multiplier*: string
        exchange*: string
        currency*: string
        localSymbol*: string
        primaryExchange*: string
        tradingClass*: string
        includeExpired*: bool
        secIdType*: SecIdType
        secId*: string
        comboLegsDescription*: string
        comboLegs*: seq[ComboLeg]
        deltaNeutralContract*: DeltaNeutralContract

    ContractDetails* = object
        contract*: Contract
        marketName*: string
        minTick*: float
        priceMagnifier*: int
        orderTypes*: string
        validExchanges*: string
        underConId*: int
        longName*: string
        contractMonth*,industry*,category*,subcategory*,timeZoneId*: string
        tradingHours*: string
        liquidHours*: string
        evRule*: string
        evMultiplier*: float
        mdSizeMultiplier*: float
        aggGroup*: int
        secIdList*: seq[tuple[tag: string, value: string]]
        underSymbol*: string
        underSecType*: SecType
        marketRuleIds*: string
        realExpirationDate*: string
        lastTradeTime*: string
        stockType*: string
        cusip*, ratings*, descAppend*, bondType*, couponType*: string
        callable*, putable*, coupon*, convertible*: bool
        maturity*: string
        issueDate*, nextOptionDate*, nextOptionType*, notes*: string

    ContractDescription* = object
        contract*: Contract
        derivativeSecTypesList*: seq[string]

    ContractDescriptionList* = seq[ContractDescription]

proc parseLiquidHours*(contract: ContractDetails): seq[tuple[marketOpen: Datetime, marketClose: Datetime]] =
    var tz: Timezone
    if "EST" in contract.timeZoneId:
        tz = tz"America/New_York"
    else:
        tz = utc()
    let liquidHours = contract.liquidHours.split(";")
    for day in liquidHours:
        if "CLOSED" in day:
            continue
        let openClose = day.split("-")
        if openClose.len == 2:
            result.add((marketOpen: parse(openClose[0],"yyyyMMdd:hhmm",tz), marketClose:parse(openClose[1],"yyyyMMdd:hhmm",tz)))

