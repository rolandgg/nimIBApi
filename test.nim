proc conv[T](x: T): auto =
  when T is float:
    return int(x)
  else:
    return float(x)

let y = conv(1)
let x = conv(2.4)

echo y
echo x

