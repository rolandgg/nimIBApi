import tables

type
  Tool = ref object
    widget: Widget
  Widget = ref object
    tools: Table[int,Tool]

proc newWidget(): Widget =
  new(result)
  result.tools = initTable[int,Tool]()

proc newTool(w: Widget) = Tool =
  new(result)
  result.w = Widget
  

proc finalizer(x: Widget) =
  echo "bla"

proc main() =
  var x: Widget = newWidget()
  x.tools
  new(x,finalizer)

if isMainModule:
  main()