import parsecsv

var p: CsvParser
p.open("stocks.csv")
p.readHeaderRow()