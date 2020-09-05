import ibEnums
import times

type
    Order* = object
        ## This object contains all order relevant fields apart from the contract to be traded

        # order identification
        orderId*: int
        clientId*: int
        permId*: int

        # main order fields
        action*: Action
        totalQuantity*: float
        orderType*: OrderType
        lmtPrice*: float
        auxPrice*: float

        # extended order fields
        tif*: TimeInForce
        activeStartTime*, activeStopTime*: string
        ocaGroup*: string
        ocaType*: OCAType
        orderRef*: string
        transmit*: bool
        parentId*: int
        blockOrder*: bool
        sweepToFill*: bool
        displaySize*: int
        triggerMethod*: TriggerMethod
        outsideRth*: bool
        hidden*: bool
        goodAfterTime*: string #format yyyymmdd hh:mm:ss (optional timezone)
        goodTillDate*: string #format yyyymmdd hh:mm:ss (optional timezone)
        overridePercentageConstraints*: bool
        rule80A*: Rule80A
        allOrNone*: bool
        minQty*: int
        percentOffset*: float
        trailStopPrice*: float
        trailingPercent*: float

        # financial advisor fields
        faGroup*: string
        faProfile*: string
        faMethod*: string
        faPercentage*: string

        # institutional (ie non-cleared) only
        openClose*: OrderOpenClose
        origin*: Origin
        shortSaleSlot*: ShortSaleSlot
        designatedLocation*: string
        exemptCode*: int

        # SMART routing fields
        discretionaryAmt*: float
        eTradeOnly*: bool
        firmQuoteOnly*: bool
        nbboPriceCap*: float
        optOutSmartRouting*: bool

        # BOX exchange order fields
        auctionStrategy*: AuctionStrategy
        startingPrice*: float
        stockRefPrice*: float
        delta*: float

        # Pegged to stock and VOL order fields
        stockRangeLower*: float
        stockRangeUpper*: float

        randomizeSize*, randomizePrice*: bool

        # Volatility order fields    
        volatility*: float
        volatilityType*: VolatilityType
        deltaNeutralOrderType*: OrderType
        deltaNeutralAuxPrice*: float
        deltaNeutralConId*: int
        deltaNeutralSettlingFirm*: string
        deltaNeutralClearingAccount*: string
        deltaNeutralClearingIntent*: string
        deltaNeutralOpenClose*: string
        deltaNeutralShortSale*: bool
        deltaNeutralShortSaleSlot*: bool
        deltaNeutralDesignatedLocation*: string
        continuousUpdate*: bool
        referencePriceType*: ReferencePriceType

        # Combo order fields
        basisPoints*: float
        basisPointsType*: BasisPointsType

        # Scale order fields
        scaleInitLevelSize*, scaleSubsLevelSize*: int
        scalePriceIncrement*, scalePriceAdjustValue*: float
        scalePriceAdjustInterval*: int
        scaleProfitOffset*: float
        scaleAutoReset*: bool
        scaleInitPosition*: int
        scaleInitFillQty*: int
        scaleRandomPercent*: bool
        scaleTable*: string

        # Hedge order fields
        hedgeType*: HedgeType
        hedgeParam*: string # 'beta=X' value for beta hedge, 'ratio=Y' for pair hedge

        # Clearing info
        account*, settlingFirm*, clearingAccount*: string
        clearingIntent*: ClearingIntent

        # Algo order fields
        
        algoStrategy*: string
        algoParams*, smartComboRoutingParams*: seq[tuple[tag: string, value: string]]
        algoId*: string

        # What-if
        whatIf*: bool

        # Not held
        notHeld*, solicited*: bool

        # models
        modelCode*: string

        # order combo legs
        # not implemented for now


        triggerPrice*: float
        adjustedOrderType*: string
        adjustedStopPrice*, adjustedStopLimitPrice*, adjustedTrailingAmount*, lmtPriceOffset*: float
        adjustableTrailingUnit*: int
        extOperator*: string

        # native cash quantity

        cashQty*: float

        # MIFID2 fields

        mifid2DecisionMaker*, mifid2DecisionAlgo*, mifid2ExecutionTrader*, mifid2ExecutionAlgo*: string

        dontUseAutoPriceForHedge*: bool
        
        isOmsContainer*: bool

        discretionaryUpToLimitPrice*: bool

        autoCancelDate*: string
        filledQuantity*: float
        refFuturesConId*: int
        autoCancelParent*: bool
        shareholder*: string
        imbalanceOnly*, routeMarketableToBbo*: bool
        parentPermId*: int64

        usePriceMgmtAlgo*: UsePriceMmgtAlgo
    OrderState* = object
        status*: string
        initMarginBefore*, maintMarginBefore*, equityWithLoanBefore*: string
        initMarginChange*, maintMarginChange*, equityWithLoanChange*, initMarginAfter*: string
        maintMarginAfter*, equityWithLoanAfter*: string
        commission*, minCommission*, maxCommission*: float
        commissionCurrency*: string
        warningText*: string
        completedTime*: string
        completedStatus*: string
    OrderStatus* = tuple[status: string, filled: float, remaining: float,
                         avgFillPrice: float, permId: int, parentId: int,
                         lastFillPrice: float, clientId: int, whyHeld: string]

proc initOrder*(): Order =
    ## Creates a new order with default settings
    ## This order is not submitable as is, at least the primary fields must be set

    # Nim defaults strings to empty, int, float to zero, bool to false, so not all fields need to be set
    # explicitely
    result.lmtPrice = UNSET_FLOAT
    result.auxPrice = UNSET_FLOAT
    result.transmit = true
    result.minQty = UNSET_INT
    result.percentOffset = UNSET_FLOAT
    result.trailStopPrice = UNSET_FLOAT
    result.trailingPercent = UNSET_FLOAT
    result.openClose = OrderOpenClose.Open
    result.origin = Origin.Customer
    result.shortSaleSlot = ShortSaleSlot.Unset
    result.exemptCode = -1
    result.eTradeOnly = true
    result.firmQuoteOnly = true
    result.nbboPriceCap = UNSET_FLOAT
    result.auctionStrategy = AuctionStrategy.Unset
    result.startingPrice = UNSET_FLOAT
    result.stockRefPrice = UNSET_FLOAT
    result.delta = UNSET_FLOAT
    result.volatility = UNSET_FLOAT
    result.volatilityType = VolatilityType.Unset
    result.deltaNeutralAuxPrice = UNSET_FLOAT
    result.referencePriceType = ReferencePriceType.Unset
    result.basisPoints = UNSET_FLOAT
    result.basisPointsType = BasisPointsType.Unset
    result.scaleInitLevelSize = UNSET_INT
    result.scaleSubsLevelSize = UNSET_INT
    result.scalePriceIncrement = UNSET_FLOAT
    result.scalePriceAdjustValue = UNSET_FLOAT
    result.scalePriceAdjustInterval = UNSET_INT
    result.scaleProfitOffset = UNSET_FLOAT
    result.scaleInitPosition = UNSET_INT
    result.scaleInitFillQty = UNSET_INT
    result.triggerPrice = UNSET_FLOAT
    result.adjustedStopPrice = UNSET_FLOAT
    result.adjustedTrailingAmount = UNSET_FLOAT
    result.lmtPriceOffset = UNSET_FLOAT
    result.cashQty = UNSET_FLOAT
    result.filledQuantity = UNSET_FLOAT
    result.refFuturesConId = UNSET_INT
    result.parentPermId = UNSET_INT64
    result.usePriceMgmtAlgo = UsePriceMmgtAlgo.Default

proc initOrderState*(): OrderState =
    
    result.commission = UNSET_FLOAT
    result.minCommission = UNSET_FLOAT
    result.maxCommission = UNSET_FLOAT
    result.completedTime = ""

    










