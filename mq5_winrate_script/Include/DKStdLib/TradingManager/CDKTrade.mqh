//+------------------------------------------------------------------+
//|                                                CDKSymbolInfo.mqh |
//|                                                  Denis Kislitsyn |
//|                                             https://kislitsyn.me |
//+------------------------------------------------------------------+
#property copyright "Denis Kislitsyn"
#property link      "https://kislitsyn.me"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

class CDKTrade : public CTrade {
public:
   bool              CDKTrade::OrderOpenOrTrade(const string symbol,const ENUM_ORDER_TYPE order_type,const double volume,
                                                const double limit_price,const double price,const double sl,const double tp,
                                                ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,
                                                const string comment="");

};

bool CDKTrade::OrderOpenOrTrade(const string symbol,const ENUM_ORDER_TYPE order_type,const double volume,
                                const double limit_price,const double price,const double sl,const double tp,
                                ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,
                                const string comment="") {
  if (order_type==ORDER_TYPE_BUY)
    return CTrade::Buy(volume, symbol, price, sl, tp, comment);
    
  if (order_type==ORDER_TYPE_SELL) 
    return CTrade::Sell(volume, symbol, price, sl, tp, comment);
  
  return CTrade::OrderOpen(symbol, order_type, volume, limit_price, price, sl, tp, type_time, expiration, comment);
}