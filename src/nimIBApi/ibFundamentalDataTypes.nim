import ibEnums
import options, times, parsexml, streams, strutils, tables, sequtils, sugar, algorithm

type
    FundamentalsError = object of CatchableError
    StatementType = enum
        ibIncomeStatement="INC", ibBalanceSheet = "BAL", ibCashflowStatement = "CAS"
    FilingType = enum
        ibAnnual = "Annual", ibQuarter = "Interim"
    Statement* = object
        periodEnd: DateTime
        periodType: string
        periodLength: int
        content: Table[string,float]
    FundamentalReport* = object
        xml*: string
        case kind*: FundamentalDataType
        of Estimates:
            cusip*: Option[string]
            isin*: Option[string]
            ticker*: Option[string]
            ric*: Option[string]
            sedol*: Option[string]
            sector*: tuple[id: int, name: string]
            closePrice*: Option[tuple[value: float, unit: string, currency: string]]
            high52week*: Option[tuple[value: float, unit: string, currency: string]]
            low52week*: Option[tuple[value: float, unit: string, currency: string]]
            marketCap*: Option[tuple[value: float, unit: string, currency: string]]
            actualsDates*: seq[tuple[date: DateTime, periodType: string]]
            #epsActuals*: seq[tuple[date: DateTime, eps: float, periodType: string]]
        of FinStatements:
            lastModified*: DateTime
            coaType*: string
            codeMap: Table[string, tuple[statementType: StatementType, itemName: string]]
            incomeStatementsA*: seq[Statement]
            incomeStatementsQ*: seq[Statement]
            balanceSheetsA*: seq[Statement]
            balanceSheetsQ*: seq[Statement]
            cashFlowStatementsA*: seq[Statement]
            cashFlowStatementsQ*: seq[Statement]
        else:
            discard

proc save*(report: FundamentalReport, fileName: string) =
    var file = newFileStream(filename, fmWrite)
    file.write(report.xml)
    file.close

proc parseReportType(xml: string): FundamentalDataType =
    var x: XmlParser
    var f = newStringStream(xml)
    open(x, f, "")
    while true:
        x.next()
        if x.kind == xmlElementOpen:
            if x.elementName == "ReportFinancialStatements":
                x.close
                return FinStatements
        if x.kind == xmlElementStart:
            if x.elementName == "REarnEstCons":
                x.close
                return Estimates
        if x.kind == xmlEof:
            raise newException(FundamentalsError,"Financial report type unknown!")

proc `[]`(report: Statement, key: string): Option[float] {.inline.} =
    if report.content.hasKey(key):
        return some(report.content[key])

proc `[]=`(report: var Statement, key: string, val: float) {.inline.} =
    report.content[key] = val

proc initStatement(periodEnd: DateTime, periodType: string, periodLength: int): Statement =
    result.periodEnd = periodEnd
    result.periodType = periodType
    result.periodLength = periodLength
    result.content = initTable[string,float]()

proc cmpStatement(x,y: Statement): int =
    if x.periodEnd < y.periodEnd:
        return -1
    elif x.periodEnd == y.periodEnd:
        return 0
    else:
        return 1

proc `[]`(report: FundamentalReport, key: string, lag: int, filingType: FilingType = ibQuarter): Option[float] =
    if report.kind == FinStatements:
        if report.codeMap.hasKey(key):
            let statementType = report.codeMap[key].statementType
            case statementType
            of ibIncomeStatement:
                case filingType
                of ibQuarter:
                    return report.incomeStatementsQ[lag][key]
                of ibAnnual:
                    return report.incomeStatementsA[lag][key]
            of ibBalanceSheet:
                case filingType
                of ibQuarter:
                    return report.balanceSheetsQ[lag][key]
                of ibAnnual:
                    return report.balanceSheetsA[lag][key]
            of ibCashflowStatement:
                case filingType:
                of ibQuarter:
                    return report.cashflowStatementsQ[lag][key]
                of ibAnnual:
                    return report.cashflowStatementsA[lag][key]

proc `[]`(report: FundamentalReport, key: string, filingType: FilingType = ibQuarter): Option[float] {.inline.} =
    return report[key,0,filingType]


proc parseSecIds(report: var FundamentalReport) =
    if report.kind != Estimates:
        return
    var x: XmlParser
    var f = newStringStream(report.xml)
    open(x, f, "")
    while true:
        x.next()
        if x.kind == xmlElementOpen:
            if x.elementName == "SecId":
                x.next()
                var id : string
                if x.kind == xmlAttribute:
                    if x.attrKey == "type":
                        id = x.attrValue
                while x.kind != xmlCharData:
                    x.next()
                case id:
                    of "CUSIP":
                        report.cusip = some(x.charData)
                    of "ISIN":
                        report.isin = some(x.charData)
                    of "RIC":
                        report.ric = some(x.charData)
                    of "TICKER":
                        report.ticker = some(x.charData)
                    of "SEDOL":
                        report.sedol = some(x.charData)
        if x.kind == xmlElementEnd:
            if x.elementName == "SecIds":
                break

proc parseSector(report: var FundamentalReport) =
    if report.kind != Estimates:
        return
    var x: XmlParser
    var f = newStringStream(report.xml)
    open(x, f, "")
    while true:
        x.next()
        if x.kind == xmlElementOpen:
            if x.elementName == "Sector":
                x.next()
                let id = parseInt(x.attrValue)
                while x.kind != xmlCharData:
                    x.next()
                var name = x.charData
                x.next()
                while x.kind == xmlCharData or x.kind == xmlWhitespace:
                    name &= x.charData
                    x.next()
                report.sector = (id: id, name: name)
        if x.kind == xmlElementEnd:
            if x.elementName == "Sector":
                break

proc parseMarketData(report: var FundamentalReport) =
    if report.kind != Estimates:
        return
    var x: XmlParser
    var f = newStringStream(report.xml)
    open(x, f, "")
    while true:
        x.next()
        if x.kind == xmlElementOpen:
            if x.elementName == "MarketDataItem":
                x.next()
                var id,unit,currency : string
                while x.kind == xmlAttribute:
                    if x.attrKey == "type":
                        id = x.attrValue 
                    if x.attrKey == "unit":
                        unit = x.attrValue 
                    if x.attrKey == "currCode":
                        currency = x.attrValue 
                    x.next()
                x.next()
                if x.kind == xmlCharData:
                    case id:
                        of "CLPRICE":
                            report.closePrice = some((value: parseFloat(x.charData), unit: unit, currency: currency))
                        of "MARKETCAP":
                            report.marketCap = some((value: parseFloat(x.charData), unit: unit, currency: currency))
                        of "52WKHIGH":
                            report.high52week = some((value: parseFloat(x.charData), unit: unit, currency: currency))
                        of "52WKLOW":
                            report.low52week = some((value: parseFloat(x.charData), unit: unit, currency: currency))
        if x.kind == xmlElementEnd:
            if x.elementName == "MarketData":
                break    

proc parseActuals(report: var FundamentalReport, valueType: string = "EPS") =
    if valueType != "EPS" or report.kind != Estimates:
        return
    var x: XmlParser
    var f = newStringStream(report.xml)
    open(x, f, "")
    while true:
        x.next()
        if x.kind == xmlElementOpen:
            if x.elementName == "FYActual":
                x.next()
                while x.kind == xmlAttribute:
                    if x.attrKey == "type":
                        if not(x.attrValue == valueType):
                            break
                    else:
                        var date: DateTime
                        var periodType: string
                        while true:
                            x.next()   
                            if x.kind == xmlElementOpen:
                                if x.elementName == "FYPeriod":
                                    x.next()
                                    while x.kind == xmlAttribute:
                                        if x.attrKey == "periodType":
                                            periodType = x.attrValue
                                        x.next()
                                elif x.elementName == "ActValue":
                                    x.next()
                                    if x.kind == xmlAttribute:
                                        if x.attrKey == "updated":
                                            date = parse(x.attrValue, "YYYY-MM-dd'T'HH:mm:ss")
                                    while x.kind != xmlCharData:
                                        x.next()
                                    report.actualsDates.add((date: date, periodType: periodType))
                            if x.kind == xmlElementEnd:
                                if x.elementName == "FYActual":
                                    break
                    x.next()
        if x.kind == xmlElementEnd:
            if x.elementName == "FYActuals":
                break
    report.actualsDates.sort do (x,y: auto) -> int:
        cmp(y.date,x.date)             

proc parseStatements(report: var FundamentalReport) =
    if report.kind != FinStatements:
        return
    var x: XmlParser
    var f = newStringStream(report.xml)
    open(x, f, "")
    while true:
        x.next()
        if x.kind == xmlElementStart:
            if x.elementName == "LastModified":
                x.next()
                if x.kind == xmlCharData:
                    report.lastModified = parse(x.charData, "YYYY-MM-dd")
        if x.kind == xmlElementOpen:
            if x.elementName == "COAType":
                while x.kind != xmlCharData:
                    x.next()
                report.coaType = x.charData
                continue
            if x.elementName == "mapItem":
                x.next()
                var key, statementType: string
                while x.kind == xmlAttribute:
                    if x.attrKey == "coaItem":
                        key = x.attrValue
                    if x.attrKey == "statementType":
                        statementType = x.attrValue
                    x.next()
                x.next()
                if x.kind == xmlCharData:    
                    report.codeMap[key] = (statementType: parseEnum[StatementType](statementType), itemName: x.charData)
                continue
            if x.elementName == "FiscalPeriod":
                var filingType: string
                var statementType: string
                var date: DateTime
                var periodLength: int = 0
                var periodType: string = ""
                x.next()
                if x.kind == xmlAttribute:
                    if x.attrKey == "Type":
                        filingType = x.attrValue
                x.next()
                if x.kind == xmlAttribute:
                    if x.attrKey == "EndDate":
                        date =  parse(x.attrValue, "YYYY-MM-dd")
                while true:
                    x.next()
                    if x.kind == xmlElementOpen:
                        if x.elementName == "Statement":
                            x.next()
                            if x.attrKey == "Type":
                                statementType = x.attrValue
                            while true:
                                x.next()
                                if x.kind == xmlElementStart:
                                    if x.elementName == "PeriodLength":
                                        x.next()
                                        periodLength = parseInt(x.charData)
                                if x.kind == xmlElementOpen:
                                    if x.elementName == "periodType":
                                        x.next()
                                        periodType = x.attrValue
                                if x.kind == xmlElementEnd:
                                    if x.elementName == "FPHeader":
                                        break  
                            var coaCode: string
                            var statement: Statement = initStatement(date, periodType, periodLength)
                            while true:
                                x.next()
                                if x.kind == xmlelementOpen:
                                    if x.elementName == "lineItem":
                                        x.next()
                                        if x.attrKey == "coaCode":
                                            coaCode = x.attrValue
                                if x.kind == xmlCharData:
                                        statement[coaCode] = parseFloat(x.charData)
                                if x.kind == xmlElementEnd:
                                    if x.elementName == "Statement":
                                        case statementType
                                        of "INC":
                                            if filingType == "Annual":
                                                report.incomeStatementsA.add(statement)
                                            else:
                                                report.incomeStatementsQ.add(statement)
                                        of "BAL":
                                            if filingType == "Annual":
                                                report.balanceSheetsA.add(statement)
                                            else:
                                                report.balanceSheetsQ.add(statement)
                                        of "CAS":
                                            if filingType == "Annual":
                                                report.cashflowStatementsA.add(statement)
                                            else:
                                                report.cashflowStatementsQ.add(statement)
                                        break
                    if x.kind == xmlElementEnd:
                        if x.elementName == "FiscalPeriod":
                            break
        if x.kind == xmlElementEnd:
            if x.elementName == "FinancialStatements":
                break
    report.incomeStatementsQ.sort(cmpStatement, SortOrder.Descending)
    report.incomeStatementsA.sort(cmpStatement, SortOrder.Descending)
    report.balanceSheetsQ.sort(cmpStatement, SortOrder.Descending)
    report.balanceSheetsA.sort(cmpStatement, SortOrder.Descending)
    report.cashflowStatementsQ.sort(cmpStatement, SortOrder.Descending)
    report.cashflowStatementsA.sort(cmpStatement, SortOrder.Descending)

proc isCumulative(report: FundamentalReport, statementType: StatementType): bool {.inline.} =
    case statementType:
    of ibIncomeStatement:
        if report.incomeStatementsQ[0].periodLength != report.incomeStatementsQ[1].periodLength:
            return true
    of ibCashflowStatement:
        if report.cashflowStatementsQ[0].periodLength != report.cashflowStatementsQ[1].periodLength:
            return true
    else:
        return false
    return false

proc initFundamentalReport*(xml: string): FundamentalReport =
    let reportType = parseReportType(xml)
    result = FundamentalReport(kind: reportType, xml: xml)
    case reportType
    of FinStatements:
        result.parseStatements
    of Estimates:
        result.parseSecIds
        result.parseSector
        result.parseMarketData
        result.parseActuals
    else:
        discard
    
proc ttm(report: FundamentalReport, key: string): float =
    assert(report.kind == FinStatements)
    if not(report.codeMap.hasKey(key)):
        return 0
    let statementType = report.codeMap[key].statementType
    var statementList: seq[Statement]
    case statementType:
    of ibIncomeStatement:
        statementList = report.incomeStatementsQ
    of ibCashflowStatement:
        statementList = report.cashflowStatementsQ
    else:
        raise newException(ValueError, "Trailing twelve month value not available for balance sheet values!")
    var weeksCovered = 0
    var ttm = 0.0
    var idx = 0
    while weeksCovered < 52:
        if idx >= statementList.len:
            break
        let statement = statementList[idx]
        var period = statement.periodLength
        let pType = statement.periodType
        if pType == "M":
            period = period div 3
            period *= 13
        if statement.content.hasKey(key):
            ttm += statement.content[key]
        weeksCovered += period
        if weeksCovered < 52:
            idx += period div 13
        elif weeksCovered > 52:
            let shift = (weeksCovered - 52) div 13
            if idx+shift >= statementList.len:
                break
            let offSet = statementList[idx+shift]
            if offSet.content.hasKey(key):
                ttm -= statement.content[key]
            weeksCovered = 52
    if weeksCovered != 52: # in this case we have a) cumulative reporting and b) idx points to a 12 month period report (i.e. annual)
        let ratio = float(weeksCovered - 52) / 52.0 # we correct by a pro rate deduction
        if statementList[idx].content.hasKey(key):
            ttm -= ratio*statementList[idx].content[key]
    return ttm

proc totalAssets*(report: FundamentalReport): Option[float] {.inline.} =
    report["ATOT"]

proc netIncome*(report: FundamentalReport): Option[float] {.inline.} =
    let ninc = report.ttm("NINC")
    if ninc != 0.0:
        return some(ninc)

proc capitalInvested*(report: FundamentalReport): Option[float] {.inline.} =
    let totalAssets = report["ATOT"]
    let cash = report["ACSH"]
    let cashAndEqv = report["ACAE"]
    let shortTermInv = report["ASTI"]
    let totalLiab = report["LTLL"]
    let totalDebt = report["STLD"]
    if totalAssets.isSome and totalLiab.isSome:
        var csh = cash.get(0) + cashAndEqv.get(0) + shortTermInv.get(0)
        return some((totalAssets.get() - csh -
                (totalLiab.get() - totalDebt.get(0))))

proc roci*(report: FundamentalReport): Option[float] =
    ## return on invested capital
    let ci = report.capitalInvested
    let income = report.ttm("NINC")
    if ci.isSome:
        return some(income / ci.get())

proc roa*(report: FundamentalReport): Option[float] =
    ## return on total assets
    let ta = report.totalAssets
    let income = report.ttm("NINC")
    if ta.isSome:
        return some(income / ta.get())

proc gpoa*(report: FundamentalReport): Option[float] =
    ## gross profit over assets
    let grossProfit = report.ttm("SGRP")
    let assets = report["ATOT"]
    if assets.isSome and grossProfit != 0:
        return some(grossProfit / assets.get())

proc gpm*(report: FundamentalReport): Option[float] =
    ## gross profit margin
    let grossProfit = report.ttm("SGRP")
    let revenue = report.ttm("RTLR")
    if revenue > 0 and grossProfit != 0:
        return some(grossProfit / revenue)

proc noa*(report: FundamentalReport): Option[float] =
    ## net operating assets ratio
    let ci = report.capitalInvested
    let assets = report["ATOT",1] #lagged by 1 as in Hirshleifer, 2004
    if ci.isSome and assets.isSome:
        return some(ci.get() / assets.get())

proc stockIssuance*(report: FundamentalReport): Option[float] =
    return some(report.ttm("FPSS")) # assume zero if no value present instead of NaN for issuance

proc debtIssuance*(report: FundamentalReport): Option[float] =
    return some(report.ttm("FPRD")) # assume zero if no value present instead of NaN for issuance

proc freeCashFlow*(report: FundamentalReport): Option[float] =
    let opInc = report.ttm("OTLO")
    let capex = report.ttm("SCEX") #capex is a negative number if negative cashflow!
    if opInc != 0 and capex != 0:
        return some(opInc + capex)

proc commonShares*(report: FundamentalReport): Option[float] =
    report["QTCO"]

proc fcfps*(report: FundamentalReport): Option[float] =
    let shares = report["QTCO"]
    let fcf = report.freeCashFlow
    if shares.isSome and fcf.isSome:
        return some(fcf.get() / shares.get())

if isMainModule:
    var file = newFileStream("data/SBUX.xml", fmRead)
    var report = FundamentalReport(kind: Estimates, xml: file.readAll())
    # report.parseMarketData
    report.parseSector
    # report.parseActuals
    # echo report.actualsDates[0].date
    echo report.sector
    # echo report.marketCap



