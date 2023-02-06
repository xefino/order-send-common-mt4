#property copyright "Xefino"
#property version   "1.00"

enum ENUM_TRADE_REQUEST_ACTIONS {
   TRADE_ACTION_DEAL       = 0x0,
   TRADE_ACTION_PENDING    = 0x1,
   TRADE_ACTION_SLTP       = 0x2,
   TRADE_ACTION_MODIFY     = 0x3,
   TRADE_ACTION_REMOVE     = 0x4,
   TRADE_ACTION_CLOSE_BY   = 0x5
};

enum ENUM_ORDER_TYPE_FILLING {
   ORDER_FILLING_FOK    = 0x0,
   ORDER_FILLING_IOC    = 0x1,
   ORDER_FILLING_RETURN = 0x2
};

enum ENUM_ORDER_TYPE_TIME {
   ORDER_TIME_GTC             = 0x0,
   ORDER_TIME_DAY             = 0x1,
   ORDER_TIME_SPECIFIED       = 0x2,
   ORDER_TIME_SPECIFIED_DAY   = 0x3
};

struct TradeRequest {
   ENUM_TRADE_REQUEST_ACTIONS Action;
   ulong                      Magic;
   ulong                      Order;
   string                     Symbol;
   double                     Volume;
   double                     Price;
   double                     StopLimit;
   double                     StopLoss;
   double                     TakeProfit;
   ulong                      Deviation;
   ENUM_ORDER_TYPE            Type;
   ENUM_ORDER_TYPE_FILLING    TypeFilling;
   ENUM_ORDER_TYPE_TIME       TypeTime;
   datetime                   Expiration;
   string                     Comment;
   ulong                      Position;
   ulong                      PositionBy;
};

