import ibContractTypes
import ibEnums

type
  ScannerParams* = object
    xml*: string

  ScannerSubscription* = object
    numberOfRows*: int
    instrument*: string
    locationCode*: string
    scanCode*: string
    abovePrice*: float
    belowPrice*: float
    aboveVolume*: int
    marketCapAbove*: float
    marketCapBelow*: float
    moodyRatingAbove*: string
    moodyRatingBelow*: string
    spRatingAbove*: string
    spRatingBelow*: string
    maturityDateAbove*: string
    maturityDateBelow*: string
    couponRateAbove*: float
    couponRateBelow*: float
    excludeConvertible*: int
    averageOptionVolumeAbove*: int
    scannerSettingPairs*: string
    stockTypeFilter*: string

  ScanData* = object
    contract*: Contract
    marketName*: string
    rank*: int
    distance*, benchmark*, projection*, legsStr*: string

  ScanDataList* = seq[ScanData]

proc initScannerSubscription*(): ScannerSubscription =
  result.numberOfRows = UNSET_INT
  result.abovePrice = UNSET_FLOAT
  result.belowPrice = UNSET_FLOAT
  result.aboveVolume = UNSET_INT
  result.marketCapAbove = UNSET_FLOAT
  result.marketCapBelow = UNSET_FLOAT
  result.couponRateAbove = UNSET_FLOAT
  result.couponRateBelow = UNSET_FLOAT
  result.excludeConvertible = UNSET_INT
  result.averageOptionVolumeAbove = UNSET_INT

