//+------------------------------------------------------------------+
//|                                                     UyathandwaFX |
//|                    Expert Advisor for MetaTrader 5               |
//+------------------------------------------------------------------+
#property copyright "Created with ChatGPT"
#property link      ""
#property version   "1.0"
#property strict

input double RiskPercent = 1.5;           // Risk per trade in %
input int TrailingStopPercent = 15;       // Trailing stop in %
input int StartHour = 11;                  // Trading start hour (server time)
input int EndHour = 17;                    // Trading end hour (server time)

double CalculateLotSize(double stopLossPips)
  {
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   if(stopLossPips <= 0 || tickValue <= 0)
      return(minLot);

   double lot = riskAmount / (stopLossPips * tickValue);
   lot = MathMax(minLot, MathFloor(lot / lotStep) * lotStep);
   return(lot);
  }

void TrailingStop()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double trailingStopPrice;
         double stopLoss = PositionGetDouble(POSITION_SL);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            trailingStopPrice = currentPrice - (TrailingStopPercent/100.0) * (currentPrice - openPrice);
            if(trailingStopPrice > stopLoss && trailingStopPrice > openPrice)
              {
               MqlTradeRequest modifyRequest;
               MqlTradeResult modifyResult;
               ZeroMemory(modifyRequest);
               modifyRequest.action = TRADE_ACTION_SLTP;
               modifyRequest.position = ticket;
               modifyRequest.symbol = _Symbol;
               modifyRequest.sl = trailingStopPrice;
               modifyRequest.tp = PositionGetDouble(POSITION_TP);

               OrderSend(modifyRequest, modifyResult);
              }
           }
        }
     }
  }

int OnInit()
  {
   Print("UyathandwaFX initialized");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Print("UyathandwaFX stopped");
  }

void OnTick()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   if(tm.hour < StartHour || tm.hour >= EndHour)
      return;

   if(PositionsTotal() == 0)
     {
      bool breakout = true;

      if(breakout)
        {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double stopLossPips = 100;
         double lot = CalculateLotSize(stopLossPips);

         double sl = price - stopLossPips * _Point;
         double tp = price + 2 * stopLossPips * _Point;

         MqlTradeRequest request;
         MqlTradeResult result;
         ZeroMemory(request);

         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.volume = lot;
         request.price = price;
         request.sl = sl;
         request.tp = tp;
         request.type = ORDER_TYPE_BUY;

         if(!OrderSend(request,result))
           {
            Print("OrderSend failed: ", GetLastError());
           }
         else
           {
            Print("Order placed successfully");
           }
        }
     }
   else
     {
      TrailingStop();
     }
  }
