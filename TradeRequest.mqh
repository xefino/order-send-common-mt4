#property copyright "Xefino"
#property version   "1.05"

// Describes the possible actions available for trade requests
enum ENUM_TRADE_REQUEST_ACTIONS {
   TRADE_ACTION_CLOSE      = 0x0,
   TRADE_ACTION_MODIFY     = 0x1,
   TRADE_ACTION_REMOVE     = 0x2,
   TRADE_ACTION_SEND       = 0x3,
   TRADE_ACTION_CLOSE_BY   = 0x4
};

// Describes possible ways of filling an order
enum ENUM_ORDER_TYPE_FILLING {
   ORDER_FILLING_FOK    = 0x0,
   ORDER_FILLING_IOC    = 0x1,
   ORDER_FILLING_RETURN = 0x2
};

// Describes the possible expiration times associated with an order
enum ENUM_ORDER_TYPE_TIME {
   ORDER_TIME_GTC             = 0x0,
   ORDER_TIME_DAY             = 0x1,
   ORDER_TIME_SPECIFIED       = 0x2,
   ORDER_TIME_SPECIFIED_DAY   = 0x3
};

// TradeRequest
// Similar to the MqlTradeRequest in MQL5, this is the payload we'll use to transfer trades
// from the order-send master to order-send slaves
class TradeRequest {
public:
   ENUM_TRADE_REQUEST_ACTIONS Action;
   ulong                      Magic;
   ulong                      Order;
   string                     Symbol;
   double                     Volume;
   double                     Price;
   double                     StopLimit;
   double                     StopLoss;
   double                     TakeProfit;
   ENUM_ORDER_TYPE            Type;
   ENUM_ORDER_TYPE_FILLING    TypeFilling;
   ENUM_ORDER_TYPE_TIME       TypeTime;
   datetime                   Expiration;
   string                     Comment;
   ulong                      Position;
   ulong                      PositionBy;
};