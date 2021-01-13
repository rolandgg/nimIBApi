import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os

var client = newIBClient()
waitFor client.connect("127.0.0.1", 4001, 1)
var contract = Contract(symbol: "MKTX", secType: SecType.Stock, currency: "USD", exchange: "SMART")
var fundamentalData = waitFor client.reqFundamentalData(contract, FundamentalDataType.Estimates)
echo fundamentalData.xml
var file = newFileStream("MKTX.xml", fmWrite)
file.write(fundamentalData.xml)
file.close