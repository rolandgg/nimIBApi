import json_serialization

type
  Foo = object
    ask: float
    bid: float


echo Json.encode Foo(bid:1, ask: 1.1)
