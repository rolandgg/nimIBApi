import times

const UNSET_INT* = 2147483647
const UNSET_FLOAT* = 1e+37
const UNSET_INT64* = 9223372036854775807
const UNSET_TIME* = fromUnix(0)

type
    TickType* {.pure.} = enum
        BID_SIZE, BID, ASK, ASK_SIZE, LAST, LAST_SIZE,
        HIGH, LOW, VOLUME, CLOSE,
        BID_OPTION_COMPUTATION,
        ASK_OPTION_COMPUTATION,
        LAST_OPTION_COMPUTATION,
        MODEL_OPTION,
        OPEN,
        LOW_13_WEEK,
        HIGH_13_WEEK,
        LOW_26_WEEK,
        HIGH_26_WEEK,
        LOW_52_WEEK,
        HIGH_52_WEEK,
        AVG_VOLUME,
        OPEN_INTEREST,
        OPTION_HISTORICAL_VOL,
        OPTION_IMPLIED_VOL,
        OPTION_BID_EXCH,
        OPTION_ASK_EXCH,
        OPTION_CALL_OPEN_INTEREST,
        OPTION_PUT_OPEN_INTEREST,
        OPTION_CALL_VOLUME,
        OPTION_PUT_VOLUME,
        INDEX_FUTURE_PREMIUM,
        BID_EXCH,
        ASK_EXCH,
        AUCTION_VOLUME,
        AUCTION_PRICE,
        AUCTION_IMBALANCE,
        MARK_PRICE,
        BID_EFP_COMPUTATION,
        ASK_EFP_COMPUTATION,

        LAST_EFP_COMPUTATION,
        OPEN_EFP_COMPUTATION,
        HIGH_EFP_COMPUTATION,
        LOW_EFP_COMPUTATION,
        CLOSE_EFP_COMPUTATION,
        LAST_TIMESTAMP,
        SHORTABLE,
        FUNDAMENTAL_RATIOS,
        RT_VOLUME,
        HALTED,
        BID_YIELD,
        ASK_YIELD,
        LAST_YIELD,
        CUST_OPTION_COMPUTATION,
        TRADE_COUNT,
        TRADE_RATE,
        VOLUME_RATE,
        LAST_RTH_TRADE,
        RT_HISTORICAL_VOL,
        IB_DIVIDENDS,
        BOND_FACTOR_MULTIPLIER,
        REGULATORY_IMBALANCE,
        NEWS_TICK,
        SHORT_TERM_VOLUME_3_MIN,
        SHORT_TERM_VOLUME_5_MIN,
        SHORT_TERM_VOLUME_10_MIN,
        DELAYED_BID,
        DELAYED_ASK,
        DELAYED_LAST,
        DELAYED_BID_SIZE,
        DELAYED_ASK_SIZE,
        DELAYED_LAST_SIZE,
        DELAYED_HIGH,
        DELAYED_LOW,
        DELAYED_VOLUME,
        DELAYED_CLOSE,
        DELAYED_OPEN,
        RT_TRD_VOLUME,
        CREDITMAN_MARK_PRICE,
        CREDITMAN_SLOW_MARK_PRICE,
        DELAYED_BID_OPTION_COMPUTATION,
        DELAYED_ASK_OPTION_COMPUTATION,
        DELAYED_LAST_OPTION_COMPUTATION,
        DELAYED_MODEL_OPTION_COMPUTATION,
        LAST_EXCH,
        LAST_REG_TIME,
        FUTURES_OPEN_INTEREST,
        AVG_OPT_VOLUME,
        DELAYED_LAST_TIMESTAMP,
        SHORTABLE_SHARES,
        NOT_SET,
    GenericTickType* {.pure.} = enum
        ShortableData = "236"
        HistoricData = "165"
        OptionHistoricVol = "104"
        OptionImpliedVol = "106"
        OptionOpenInterest = "101"
        AuctionData = "225"
        OptionVolume = "100"
    SecType* {.pure.} = enum 
        Unset = ""
        Stock = "STK"
        Option = "OPT"
        Future = "FUT"
        OptionOnFuture = "FOP"
        Index = "IND"
        Forex = "CASH"
        Combo = "BAG"
        Warrant = "WAR"
        Bond = "BOND"
        Commodity = "CMDTY"
        News = "NEWS"
        MutualFund = "FUND"

    OptionRight* {.pure.} = enum
        Unset = ""
        Undefined = "?"
        Put = "PUT"
        Call = "CALL"

    SecIdType* {.pure.} = enum

        Unset = ""
        ISIN = "ISIN"
        CUSIP = "CUSIP"

    ComboAction* {.pure.} = enum
        Unset = ""
        Buy = "BUY"
        Sell = "SELL"
        ShortSell = "SSELL"

    OptionOpenClose* {.pure.} = enum
        Same = 0
        Open = 1
        Close = 2
        Unkown = 3
        Unset = UNSET_INT
        
    ShortSaleSlot* {.pure.} = enum
        None = 0
        Broker = 1
        ThirdParty = 2
        Unset = UNSET_INT

    Action* {.pure.} = enum
        Unset = ""
        Buy = "BUY"
        Sell = "SELL"
        SellShort = "SSELL"
        SellLong = "SLONG"

    OrderType* {.pure.} = enum
        Unset = ""
        None = "None" #only legit for deltaNeutralOrderType
        Limit = "LMT"
        Market = "MKT"
        MarketIfTouched = "MIT"
        MarketOnClose = "MOC"
        MarketOnOpen = "MOO"
        PeggedToMarket = "PEG MKT"
        PeggedToStock = "PEG STK"
        PeggedToPrimary = "REL"
        BoxTop = "BOX TOP"
        LimitIfTouched = "LIT"
        LimitOnClose = "LOC"
        PassiveRelative = "PASSV REL"
        PeggedToMidpoint = "PEG MID"
        MarketToLimit = "MTL"
        MarketWithProtection = "MKT PRT"
        Stop = "STP"
        StopLimit = "STP LMT"
        StopWithProtection = "STP PRT"
        TrailingStop = "TRAIL"
        TrailingStopLimit = "TRAIL LIMIT"
        RelativeLimit = "Rel + LMT"
        RelativeMarket = "Rel + MKT"
        Volatility = "VOL"
        PeggedToBenchmark = "PEG BENCH"

    TriggerMethod* {.pure.} = enum
        Default = 0
        DoubleBidAsk = 1
        Last = 2
        DoubleLast = 3
        BidAsk = 4
        LastOrBidAsk = 7
        MidPoint = 8
        Unset = UNSET_INT

    TimeInForce* {.pure.} = enum
        Unset = ""
        Day = "DAY"
        GoodTillCancel = "GTC"
        ImmediateOrCancel = "IOC"
        GoodUntilDate = "GTD"
        GoodOnOpen = "OPG"
        FillOrKill = "FOK"
        DayUntilCancel = "DTC"

    Rule80A* {.pure.} = enum
        Unset = ""
        Individual = "I"
        Agency = "A"
        AgentOtherMember = "W"
        IndividualPTIA = "J"
        AgencyPTIA = "U"
        AgentOtherMemberPTIA = "M"
        IndividualPT = "K"
        AgencyPT = "Y"
        AgentOtherMemberPT = "N"

    OrderOpenClose* {.pure.} = enum
        Unset = ""
        Open = "O"
        Close = "C"

    Origin* {.pure.} = enum
        Customer, Firm, Unknown, Unset = UNSET_INT

    AuctionStrategy* {.pure.} = enum
        None, Match, Improvement, Transparent, Unset = UNSET_INT

    OCAType* {.pure.} = enum
        None, CancelWithBlock, ReduceWithBlock, ReduceNonBlock, Unset = UNSET_INT

    VolatilityType* {.pure.} = enum
        None, Daily, Annual, Unset = UNSET_INT

    ReferencePriceType* {.pure.} = enum
        None, Average, BidOrAsk, Unset = UNSET_INT

    BasisPointsType* {.pure.} = enum
        Undefined="?", Unset = ""
    
    HedgeType* {.pure.} = enum
        Unset = ""
        Undefined = "?"
        Delta = "D"
        Beta = "B"
        FX = "F"
        Pair = "P"

    ClearingIntent* {.pure.} = enum
        Default = ""
        IB = "IB"
        Away = "Away"
        PTA = "PTA"

    UsePriceMmgtAlgo* {.pure.} = enum
        DontUse, Use, Default = UNSET_INT

    Side* {.pure.} = enum
        Unset = ""
        Long = "BOT"
        Short = "SLD"

    IBAccountField* {.pure.} = enum
        AccountType = "AccountType" 
        NetLiquidation = "NetLiquidation"
        TotalCashValue = "TotalCashValue"
        SettledCash = "SettledCash"
        AccruedCash = "AccruedCash"
        BuyingPower = "BuyingPower"
        EquityWithLoanValue = "EquityWithLoanValue"
        PreviousEquityWithLoanValue = "PreviousEquityWithLoanValue"
        GrossPositionValue = "GrossPositionValue"
        ReqTEquity = "ReqTEquity"
        ReqTMargin = "ReqTMargin"
        SMA = "SMA"
        InitMarginReq = "InitMarginReq"
        MaintMarginReq = "MaintMarginReq"
        AvailableFunds = "AvailableFunds"
        ExcessLiquidity = "ExcessLiquidity"
        Cushion = "Cushion"
        FullInitMarginReq = "FullInitMarginReq"
        FullMaintMarginReq = "FullMaintMarginReq"
        FullAvailableFunds = "FullAvailableFunds"
        FullExcessLiquidity = "FullExcessLiquidity"
        LookAheadNextChange = "LookAheadNextChange"
        LookAheadInitMarginReq = "LookAheadInitMarginReq"
        LookAheadMaintMarginReq = "LookAheadMaintMarginReq"
        LookAheadAvailableFunds = "LookAheadAvailableFunds"
        LookAheadExcessLiquidity = "LookAheadExcessLiquidity"
        HighestSeverity = "HighestSeverity"
        DayTradesRemaining = "DayTradesRemaining"
        Leverage = "Leverage"

