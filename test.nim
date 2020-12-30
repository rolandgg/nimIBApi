import options

proc encode[T](val: T) =
  when T is Option:
    echo "bla"
    echo typeof(val.get())
  else:
    echo "blah"

encode(1.0)
encode(some(1.0))