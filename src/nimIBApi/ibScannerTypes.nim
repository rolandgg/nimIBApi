import options
import ibContractTypes

type
  ScannerParams* = object
    xml*: string

  ScannerSubscription* = object
    numberOfRows: Option[int]
    instrument: string
    locationCode: string
    scanCode: string
    abovePrice: Option[float]
    belowPrice: Option[float]
    aboveVolume: Option[int]
    marketCapAbove: Option[float]
    marketCapBelow: Option[float]
    moodyRatingAbove: string
    moodyRatingBelow: string
    spRatingAbove: string
    spRatingBelow: string
    maturityDateAbove: string
    maturityDateBelow: string
    couponRateAbove: Option[float]
    couponRateBelow: Option[float]
    excludeConvertible: Option[int]
    averageOptionVolumeAbove: Option[int]
    scannerSettingPairs: string
    stockTypeFilter: string

  ScanData* = object
    contract*: ContractDetails
    rank*: int
    distance*, benchmark*, projection*, legsStr*: string



