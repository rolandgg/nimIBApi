import times

type
    Bar* = tuple[
        tstamp: Time,
        open, high, low, close, wap: float,
        volume: int64,
        count: int,
    ]
    BarSeries* = object
        startDT*, endDT*: string
        nBars*: int
        data*: seq[Bar]
