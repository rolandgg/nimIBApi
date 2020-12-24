import results


type
  R = Result[int,string]

var res: R = R.ok 42

var res2: R = R.err "error"

