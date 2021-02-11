import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os


var file = newFileStream("/Users/rolandgrein/codes/riskpremia/data/TGT_reports.xml", fmRead)
var report = initFundamentalReport(file.readAll)
echo report.freeCashFlow