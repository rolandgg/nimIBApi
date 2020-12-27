import ../src/ibApi
import asyncdispatch
import streams
import strutils, strformat, os

var client = newIBClient()
waitFor client.connect("127.0.0.1", 4002, 1)
let params = waitFor client.reqScannerParams()
var file = newFileStream("scanner.xml", fmWrite)
file.write(params.xml)
file.close