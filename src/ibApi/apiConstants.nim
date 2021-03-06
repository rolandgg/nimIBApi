const
  ## client API version
  CLIENT_VERSION                = 66
  ## outgoing message IDs
  REQ_MKT_DATA                  = 1 
  CANCEL_MKT_DATA               = 2 
  PLACE_ORDER                   = 3 
  CANCEL_ORDER                  = 4 
  REQ_OPEN_ORDERS               = 5 
  REQ_ACCT_DATA                 = 6 
  REQ_EXECUTIONS                = 7 
  REQ_IDS                       = 8 
  REQ_CONTRACT_DATA             = 9 
  REQ_MKT_DEPTH                 = 10 
  CANCEL_MKT_DEPTH              = 11 
  REQ_NEWS_BULLETINS            = 12 
  CANCEL_NEWS_BULLETINS         = 13 
  SET_SERVER_LOGLEVEL           = 14 
  REQ_AUTO_OPEN_ORDERS          = 15 
  REQ_ALL_OPEN_ORDERS           = 16 
  REQ_MANAGED_ACCTS             = 17 
  REQ_FA                        = 18 
  REPLACE_FA                    = 19 
  REQ_HISTORICAL_DATA           = 20 
  EXERCISE_OPTIONS              = 21 
  REQ_SCANNER_SUBSCRIPTION      = 22 
  CANCEL_SCANNER_SUBSCRIPTION   = 23 
  REQ_SCANNER_PARAMETERS        = 24 
  CANCEL_HISTORICAL_DATA        = 25 
  REQ_CURRENT_TIME              = 49 
  REQ_REAL_TIME_BARS            = 50 
  CANCEL_REAL_TIME_BARS         = 51 
  REQ_FUNDAMENTAL_DATA          = 52 
  CANCEL_FUNDAMENTAL_DATA       = 53 
  REQ_CALC_IMPLIED_VOLAT        = 54 
  REQ_CALC_OPTION_PRICE         = 55 
  CANCEL_CALC_IMPLIED_VOLAT     = 56 
  CANCEL_CALC_OPTION_PRICE      = 57 
  REQ_GLOBAL_CANCEL             = 58 
  REQ_MARKET_DATA_TYPE          = 59 
  REQ_POSITIONS                 = 61 
  REQ_ACCOUNT_SUMMARY           = 62 
  CANCEL_ACCOUNT_SUMMARY        = 63 
  CANCEL_POSITIONS              = 64 
  VERIFY_REQUEST                = 65 
  VERIFY_MESSAGE                = 66 
  QUERY_DISPLAY_GROUPS          = 67 
  SUBSCRIBE_TO_GROUP_EVENTS     = 68 
  UPDATE_DISPLAY_GROUP          = 69 
  UNSUBSCRIBE_FROM_GROUP_EVENTS = 70 
  START_API                     = 71 
  VERIFY_AND_AUTH_REQUEST       = 72 
  VERIFY_AND_AUTH_MESSAGE       = 73 
  REQ_POSITIONS_MULTI           = 74 
  CANCEL_POSITIONS_MULTI        = 75 
  REQ_ACCOUNT_UPDATES_MULTI     = 76 
  CANCEL_ACCOUNT_UPDATES_MULTI  = 77 
  REQ_SEC_DEF_OPT_PARAMS        = 78 
  REQ_SOFT_DOLLAR_TIERS         = 79 
  REQ_FAMILY_CODES              = 80 
  REQ_MATCHING_SYMBOLS          = 81 
  REQ_MKT_DEPTH_EXCHANGES       = 82 
  REQ_SMART_COMPONENTS          = 83 
  REQ_NEWS_ARTICLE              = 84 
  REQ_NEWS_PROVIDERS            = 85 
  REQ_HISTORICAL_NEWS           = 86 
  REQ_HEAD_TIMESTAMP            = 87 
  REQ_HISTOGRAM_DATA            = 88 
  CANCEL_HISTOGRAM_DATA         = 89 
  CANCEL_HEAD_TIMESTAMP         = 90 
  REQ_MARKET_RULE               = 91 
  REQ_PNL                       = 92 
  CANCEL_PNL                    = 93 
  REQ_PNL_SINGLE                = 94 
  CANCEL_PNL_SINGLE             = 95 
  REQ_HISTORICAL_TICKS          = 96 
  REQ_TICK_BY_TICK_DATA         = 97 
  CANCEL_TICK_BY_TICK_DATA      = 98 
  REQ_COMPLETED_ORDERS          = 99 

  # server versions
  MIN_SERVER_VER_PTA_ORDERS                 = 39
  MIN_SERVER_VER_FUNDAMENTAL_DATA           = 40
  MIN_SERVER_VER_DELTA_NEUTRAL              = 40
  MIN_SERVER_VER_CONTRACT_DATA_CHAIN        = 40
  MIN_SERVER_VER_SCALE_ORDERS2              = 40
  MIN_SERVER_VER_ALGO_ORDERS                = 41
  MIN_SERVER_VER_EXECUTION_DATA_CHAIN       = 42
  MIN_SERVER_VER_NOT_HELD                   = 44
  MIN_SERVER_VER_SEC_ID_TYPE                = 45
  MIN_SERVER_VER_PLACE_ORDER_CONID          = 46
  MIN_SERVER_VER_REQ_MKT_DATA_CONID         = 47
  MIN_SERVER_VER_REQ_CALC_IMPLIED_VOLAT     = 49
  MIN_SERVER_VER_REQ_CALC_OPTION_PRICE      = 50
  MIN_SERVER_VER_CANCEL_CALC_IMPLIED_VOLAT  = 50
  MIN_SERVER_VER_CANCEL_CALC_OPTION_PRICE   = 50
  MIN_SERVER_VER_SSHORTX_OLD                = 51
  MIN_SERVER_VER_SSHORTX                    = 52
  MIN_SERVER_VER_REQ_GLOBAL_CANCEL          = 53
  MIN_SERVER_VER_HEDGE_ORDERS               = 54
  MIN_SERVER_VER_REQ_MARKET_DATA_TYPE       = 55
  MIN_SERVER_VER_OPT_OUT_SMART_ROUTING      = 56
  MIN_SERVER_VER_SMART_COMBO_ROUTING_PARAMS = 57
  MIN_SERVER_VER_DELTA_NEUTRAL_CONID        = 58
  MIN_SERVER_VER_SCALE_ORDERS3              = 60
  MIN_SERVER_VER_ORDER_COMBO_LEGS_PRICE     = 61
  MIN_SERVER_VER_TRAILING_PERCENT           = 62
  MIN_SERVER_VER_DELTA_NEUTRAL_OPEN_CLOSE   = 66
  MIN_SERVER_VER_POSITIONS                  = 67
  MIN_SERVER_VER_ACCOUNT_SUMMARY            = 67
  MIN_SERVER_VER_TRADING_CLASS              = 68
  MIN_SERVER_VER_SCALE_TABLE                = 69
  MIN_SERVER_VER_LINKING                    = 70
  MIN_SERVER_VER_ALGO_ID                    = 71
  MIN_SERVER_VER_OPTIONAL_CAPABILITIES      = 72
  MIN_SERVER_VER_ORDER_SOLICITED            = 73
  MIN_SERVER_VER_LINKING_AUTH               = 74
  MIN_SERVER_VER_PRIMARYEXCH                = 75
  MIN_SERVER_VER_RANDOMIZE_SIZE_AND_PRICE   = 76
  MIN_SERVER_VER_FRACTIONAL_POSITIONS       = 101
  MIN_SERVER_VER_PEGGED_TO_BENCHMARK        = 102
  MIN_SERVER_VER_MODELS_SUPPORT             = 103
  MIN_SERVER_VER_SEC_DEF_OPT_PARAMS_REQ     = 104
  MIN_SERVER_VER_EXT_OPERATOR               = 105
  MIN_SERVER_VER_SOFT_DOLLAR_TIER           = 106
  MIN_SERVER_VER_REQ_FAMILY_CODES           = 107
  MIN_SERVER_VER_REQ_MATCHING_SYMBOLS       = 108
  MIN_SERVER_VER_PAST_LIMIT                 = 109
  MIN_SERVER_VER_MD_SIZE_MULTIPLIER         = 110
  MIN_SERVER_VER_CASH_QTY                   = 111
  MIN_SERVER_VER_REQ_MKT_DEPTH_EXCHANGES    = 112
  MIN_SERVER_VER_TICK_NEWS                  = 113
  MIN_SERVER_VER_REQ_SMART_COMPONENTS       = 114
  MIN_SERVER_VER_REQ_NEWS_PROVIDERS         = 115
  MIN_SERVER_VER_REQ_NEWS_ARTICLE           = 116
  MIN_SERVER_VER_REQ_HISTORICAL_NEWS        = 117
  MIN_SERVER_VER_REQ_HEAD_TIMESTAMP         = 118
  MIN_SERVER_VER_REQ_HISTOGRAM              = 119
  MIN_SERVER_VER_SERVICE_DATA_TYPE          = 120
  MIN_SERVER_VER_AGG_GROUP                  = 121
  MIN_SERVER_VER_UNDERLYING_INFO            = 122
  MIN_SERVER_VER_CANCEL_HEADTIMESTAMP       = 123
  MIN_SERVER_VER_SYNT_REALTIME_BARS         = 124
  MIN_SERVER_VER_CFD_REROUTE                = 125
  MIN_SERVER_VER_MARKET_RULES               = 126
  MIN_SERVER_VER_DAILY_PNL                  = 127
  MIN_SERVER_VER_PNL                        = 127
  MIN_SERVER_VER_NEWS_QUERY_ORIGINS         = 128
  MIN_SERVER_VER_UNREALIZED_PNL             = 129
  MIN_SERVER_VER_HISTORICAL_TICKS           = 130
  MIN_SERVER_VER_MARKET_CAP_PRICE           = 131
  MIN_SERVER_VER_PRE_OPEN_BID_ASK           = 132
  MIN_SERVER_VER_REAL_EXPIRATION_DATE       = 134
  MIN_SERVER_VER_REALIZED_PNL               = 135
  MIN_SERVER_VER_LAST_LIQUIDITY             = 136
  MIN_SERVER_VER_TICK_BY_TICK               = 137
  MIN_SERVER_VER_DECISION_MAKER             = 138
  MIN_SERVER_VER_MIFID_EXECUTION            = 139
  MIN_SERVER_VER_TICK_BY_TICK_IGNORE_SIZE   = 140
  MIN_SERVER_VER_AUTO_PRICE_FOR_HEDGE       = 141
  MIN_SERVER_VER_WHAT_IF_EXT_FIELDS         = 142
  MIN_SERVER_VER_SCANNER_GENERIC_OPTS       = 143
  MIN_SERVER_VER_API_BIND_ORDER             = 144
  MIN_SERVER_VER_ORDER_CONTAINER            = 145
  MIN_SERVER_VER_SMART_DEPTH                = 146
  MIN_SERVER_VER_REMOVE_NULL_ALL_CASTING    = 147
  MIN_SERVER_VER_D_PEG_ORDERS               = 148
  MIN_SERVER_VER_MKT_DEPTH_PRIM_EXCHANGE    = 149
  MIN_SERVER_VER_COMPLETED_ORDERS           = 150
  MIN_SERVER_VER_PRICE_MGMT_ALGO            = 151

  # 100+ messaging 
  # 100 = enhanced handshake, msg length prefixes

  MIN_CLIENT_VER = 100
  MAX_CLIENT_VER = MIN_SERVER_VER_PRICE_MGMT_ALGO


  # incoming msg id's
type 
  Incoming* {.pure.} = enum
    TICK_PRICE                                = 1
    TICK_SIZE                                 = 2
    ORDER_STATUS                              = 3
    ERR_MSG                                   = 4
    OPEN_ORDER                                = 5
    ACCT_VALUE                                = 6
    PORTFOLIO_VALUE                           = 7
    ACCT_UPDATE_TIME                          = 8
    NEXT_VALID_ID                             = 9
    CONTRACT_DATA                             = 10
    EXECUTION_DATA                            = 11
    MARKET_DEPTH                              = 12
    MARKET_DEPTH_L2                           = 13
    NEWS_BULLETINS                            = 14
    MANAGED_ACCTS                             = 15
    RECEIVE_FA                                = 16
    HISTORICAL_DATA                           = 17
    BOND_CONTRACT_DATA                        = 18
    SCANNER_PARAMETERS                        = 19
    SCANNER_DATA                              = 20
    TICK_OPTION_COMPUTATION                   = 21
    TICK_GENERIC                              = 45
    TICK_STRING                               = 46
    TICK_EFP                                  = 47
    CURRENT_TIME                              = 49
    REAL_TIME_BARS                            = 50
    FUNDAMENTAL_DATA                          = 51
    CONTRACT_DATA_END                         = 52
    OPEN_ORDER_END                            = 53
    ACCT_DOWNLOAD_END                         = 54
    EXECUTION_DATA_END                        = 55
    DELTA_NEUTRAL_VALIDATION                  = 56
    TICK_SNAPSHOT_END                         = 57
    MARKET_DATA_TYPE                          = 58
    COMMISSION_REPORT                         = 59
    POSITION_DATA                             = 61
    POSITION_END                              = 62
    ACCOUNT_SUMMARY                           = 63
    ACCOUNT_SUMMARY_END                       = 64
    VERIFY_MESSAGE_API                        = 65
    VERIFY_COMPLETED                          = 66
    DISPLAY_GROUP_LIST                        = 67
    DISPLAY_GROUP_UPDATED                     = 68
    VERIFY_AND_AUTH_MESSAGE_API               = 69
    VERIFY_AND_AUTH_COMPLETED                 = 70
    POSITION_MULTI                            = 71
    POSITION_MULTI_END                        = 72
    ACCOUNT_UPDATE_MULTI                      = 73
    ACCOUNT_UPDATE_MULTI_END                  = 74
    SECURITY_DEFINITION_OPTION_PARAMETER      = 75
    SECURITY_DEFINITION_OPTION_PARAMETER_END  = 76
    SOFT_DOLLAR_TIERS                         = 77
    FAMILY_CODES                              = 78
    SYMBOL_SAMPLES                            = 79
    MKT_DEPTH_EXCHANGES                       = 80
    TICK_REQ_PARAMS                           = 81
    SMART_COMPONENTS                          = 82
    NEWS_ARTICLE                              = 83
    TICK_NEWS                                 = 84
    NEWS_PROVIDERS                            = 85
    HISTORICAL_NEWS                           = 86
    HISTORICAL_NEWS_END                       = 87
    HEAD_TIMESTAMP                            = 88
    HISTOGRAM_DATA                            = 89
    HISTORICAL_DATA_UPDATE                    = 90
    REROUTE_MKT_DATA_REQ                      = 91
    REROUTE_MKT_DEPTH_REQ                     = 92
    MARKET_RULE                               = 93
    PNL                                       = 94
    PNL_SINGLE                                = 95
    HISTORICAL_TICKS                          = 96
    HISTORICAL_TICKS_BID_ASK                  = 97
    HISTORICAL_TICKS_LAST                     = 98
    TICK_BY_TICK                              = 99
    ORDER_BOUND                               = 100
    COMPLETED_ORDER                           = 101
    COMPLETED_ORDERS_END                      = 102

const
  HEADER_LEN = 4 # 4 bytes for msg length
  MAX_MSG_LEN = 0xFFFFFF # 16Mb - 1byte
  API_SIGN: string = "API\0" # "API"

  ## TWS New Bulletins constants
  NEWS_MSG              = 1     # standard IB news bulleting message
  EXCHANGE_AVAIL_MSG    = 2     # control message specifing that an exchange is available for trading
  EXCHANGE_UNAVAIL_MSG  = 3     # control message specifing that an exchange is unavailable for trading