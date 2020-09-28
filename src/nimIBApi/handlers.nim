import utils, ibContractTypes, ibOrderTypes, ibExecutionTypes, ibMarketDataTypes, ibEnums, ibTickTypes
import OrderTracker

import bitops

type
    OrderId* = int


# Request handlers

proc handle*[T](payload: seq[string]): T =
    var fields = newFieldStream(payload)
    when T is ContractDetails:
        fields.skip #skip version
        fields.skip #skio reqId
        # parse the contract object
        var contract = Contract()
        contract.symbol << fields
        contract.secType << fields
        contract.lastTradeDateOrContractMonth << fields
        contract.strike << fields
        contract.right << fields
        contract.exchange << fields
        contract.currency << fields
        contract.localSymbol << fields
        result.marketName << fields
        contract.tradingClass << fields
        contract.conId << fields
        result.minTick << fields
        result.mdSizeMultiplier << fields
        contract.multiplier << fields
        result.orderTypes << fields
        result.validExchanges << fields
        result.priceMagnifier << fields
        result.underConId << fields
        result.longName << fields
        contract.primaryExchange << fields
        result.contractMonth << fields
        result.industry << fields
        result.category << fields
        result.subcategory << fields
        result.timeZoneId << fields
        result.tradingHours << fields
        result.liquidHours << fields
        result.evRule << fields
        result.evMultiplier << fields
        var secIdListCount: int
        secIdListCount << fields
        result.secIdList = @[]
        if secIdListCount != UNSET_INT and secIdListCount > 0:
            var tag, value: string
            for i in 0..secIdListCount-1:
                tag << fields
                value << fields
                result.secIdList.add((tag: tag, value: value))
        result.aggGroup << fields
        result.underSymbol << fields
        result.underSecType << fields
        result.marketRuleIds << fields
        result.realExpirationDate << fields
        result.contract = contract

    when T is BarSeries:
        fields.skip
        result.startDT << fields
        result.endDT << fields
        result.nBars << fields
        result.data = newSeq[Bar](result.nBars)
        var tstamp: string
        for i in 0..result.data.len-1:
            tstamp << fields
            if tstamp.len == 8:
                result.data[i].tstamp = parse(tstamp, "yyyyMMdd").toTime
            result.data[i].open << fields
            result.data[i].high << fields
            result.data[i].low << fields
            result.data[i].close << fields
            result.data[i].volume << fields
            result.data[i].wap << fields
            result.data[i].count << fields

    when T is OrderID:
        result = OrderID(parseInt(payload[1]))

    when T is OrderTracker:
        var order = initOrder()
        var contract = Contract()
        var orderState = initOrderState()
        order.orderId << fields
        # decode contract info
        contract.conId << fields
        contract.symbol << fields
        contract.secType << fields
        contract.lastTradeDateOrContractMonth << fields
        contract.strike << fields
        contract.right << fields
        contract.multiplier << fields
        contract.exchange << fields
        contract.currency << fields
        contract.localSymbol << fields
        contract.tradingClass << fields
        # decode order info
        order.action << fields
        order.totalQuantity << fields
        order.orderType << fields
        order.lmtPrice << fields
        order.auxPrice << fields
        order.tif << fields
        order.ocaGroup << fields
        order.account << fields
        order.openClose << fields
        order.origin << fields
        order.orderRef << fields
        order.clientId << fields
        order.permId << fields
        order.outsideRth << fields
        order.hidden << fields
        order.discretionaryAmt << fields
        order.goodAfterTime << fields
        fields.skip # sharesAllocation is swallowed in C++ API
        order.faGroup << fields
        order.faMethod << fields
        order.faPercentage << fields
        order.faProfile << fields
        order.modelCode << fields
        order.goodTillDate << fields
        order.rule80A << fields
        order.percentOffset << fields
        order.settlingFirm << fields
        order.shortSaleSlot << fields
        order.designatedLocation << fields
        order.exemptCode << fields
        order.auctionStrategy << fields
        order.startingPrice << fields
        order.stockRefPrice << fields
        order.delta << fields
        order.stockRangeLower << fields
        order.stockRangeUpper << fields
        order.displaySize << fields
        order.blockOrder << fields
        order.sweepToFill << fields
        order.allOrNone << fields
        order.minQty << fields
        order.ocaType << fields
        order.eTradeOnly << fields
        order.firmQuoteOnly << fields
        order.nbboPriceCap << fields
        order.parentId << fields
        order.triggerMethod << fields
        order.volatility << fields
        order.volatilityType << fields
        order.deltaNeutralOrderType << fields
        order.deltaNeutralAuxPrice << fields
        if order.deltaNeutralOrderType != OrderType.Unset:
            order.deltaNeutralConId << fields
            order.deltaNeutralSettlingFirm << fields
            order.deltaNeutralClearingAccount << fields
            order.deltaNeutralClearingIntent << fields
            order.deltaNeutralOpenClose << fields
            order.deltaNeutralShortSale << fields
            order.deltaNeutralShortSaleSlot << fields
            order.deltaNeutralDesignatedLocation << fields
        order.continuousUpdate << fields
        order.referencePriceType << fields
        order.trailStopPrice << fields
        order.trailingPercent << fields
        order.basisPoints << fields
        order.basisPointsType << fields
        fields.skip # skip comboLegsDescrip
        fields.skip # skip comboLegsCount
        fields.skip # skip 
        var smartComboRoutingParamsCount: int
        smartComboRoutingParamsCount << fields
        order.smartComboRoutingParams = @[]
        var tag, value: string
        for i in 0..smartComboRoutingParamsCount-1:
            tag << fields
            value << fields
            order.smartComboRoutingParams.add((tag: tag, value: value))
        order.scaleInitLevelSize << fields
        order.scaleSubsLevelSize << fields
        order.scalePriceIncrement << fields
        if (order.scalePriceIncrement > 0 and order.scalePriceIncrement != UNSET_FLOAT):
            order.scalePriceAdjustValue << fields
            order.scalePriceAdjustInterval << fields
            order.scaleProfitOffset << fields
            order.scaleAutoReset << fields
            order.scaleInitPosition << fields
            order.scaleInitFillQty << fields
            order.scaleRandomPercent << fields
        order.hedgeType << fields
        if order.hedgeType != HedgeType.Unset and order.hedgeType != HedgeType.Undefined:
            order.hedgeParam << fields
        order.optOutSmartRouting << fields
        order.clearingAccount << fields
        order.clearingIntent << fields
        order.notHeld << fields
        fields.skip # delta Neutral contract not supported
        order.algoStrategy << fields
        # algoStrategy not supported!
        order.solicited << fields
        order.whatIf << fields
        orderState.status << fields
        orderState.initMarginBefore << fields
        orderState.maintMarginBefore << fields
        orderState.equityWithLoanBefore << fields
        orderState.initMarginChange << fields
        orderState.maintMarginChange << fields
        orderState.equityWithLoanChange << fields
        orderState.initMarginAfter << fields
        orderState.maintMarginAfter << fields
        orderState.equityWithLoanAfter << fields
        orderState.commission << fields
        orderState.minCommission << fields
        orderState.maxCommission << fields
        orderState.commissionCurrency << fields
        orderState.warningText << fields
        order.randomizeSize << fields
        order.randomizePrice << fields
        # PEG BENCH orders not supported!
        fields.skip # order conditions not supported!
        order.adjustedOrderType << fields
        order.triggerPrice << fields
        order.trailStopPrice << fields
        order.lmtPriceOffset << fields
        order.adjustedStopPrice << fields
        order.adjustedStopLimitPrice << fields
        order.adjustedTrailingAmount << fields
        order.adjustableTrailingUnit << fields
        fields.skip #SoftDollarTier not supported
        fields.skip
        fields.skip 
        order.cashQty << fields
        order.dontUseAutoPriceForHedge << fields
        order.isOmsContainer << fields
        order.discretionaryUpToLimitPrice << fields
        order.usePriceMgmtAlgo << fields
        return newOrderTracker(contract, order, orderState)
    
    when T is Execution:
        fields.skip # skip the reqId here
        result.orderId << fields
        var contract: Contract
        contract.conId << fields
        contract.symbol << fields
        contract.secType << fields
        contract.lastTradeDateOrContractMonth << fields
        contract.strike << fields
        contract.right << fields
        contract.multiplier << fields
        contract.exchange << fields
        contract.currency << fields
        contract.localSymbol << fields
        contract.tradingClass << fields
        result.contract = contract
        result.execId << fields
        result.time << fields
        result.acctNumber << fields
        result.exchange << fields
        result.side << fields
        result.shares << fields
        result.price << fields
        result.permId << fields
        result.clientId << fields
        result.liquidation << fields
        result.cumQty << fields
        result.avgPrice << fields
        result.orderRef << fields
        result.evRule << fields
        result.evMultiplier << fields
        result.modelCode << fields
        result.lastLiquidity << fields

    when T is CommissionReport:
        fields.skip # skip version
        result.execId << fields
        result.commission << fields
        result.currency << fields
        result.realizedPnL << fields
        result.yieldAmount << fields
        result.yieldRedemptionDate << fields

    when T is PriceTick:
        fields.skip # skip version
        fields.skip # skip tickerId here
        var kind: TickType
        kind << fields
        result = PriceTick(kind: kind)
        result.price << fields
        case kind
        of TickType.Bid, TickType.Ask, TickType.Last,
            TickType.DelayedBid, TickType.DelayedAsk, TickType.DelayedLast:
            result.size << fields
        else:
            fields.skip
        var attrMask: int32
        attrMask << fields
        result.attributes = {}
        if testBit(attrMask,0):
            result.attributes.incl(taCanAutoExecute)
        if testBit(attrMask,1):
            result.attributes.incl(taPastLimit)
        if testBit(attrMask,2):
            result.attributes.incl(taPreOpen)
    
    when T is SizeTick: 
        fields.skip
        fields.skip
        result.kind << fields
        result.size << fields
    
    when T is StringTick or T is GenericTick:
        fields.skip
        fields.skip
        result.kind << fields
        result.value << fields




