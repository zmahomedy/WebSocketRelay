//+------------------------------------------------------------------+
//| Test_WebSocket_Echo_EA.mq5                                       |
//+------------------------------------------------------------------+
#property strict

#include <WebRelay/WebSocketsv2/Protocol/CWebSocketClient.mqh>
#include <WebRelay/Util/Log.mqh>
#include "CTestWsListener.mqh"

input string InpHost = "echo.websocket.events";
input int    InpPort = 443;
input string InpPath = "/";
input bool   InpTLS  = true;
input int    InpTimeoutMs = 5000;

input bool InpIdleHB        = true;
input int  InpHBIntervalMs  = 10000;
input int  InpHBTimeoutMs   = 3000;
input int  InpHBGraceMiss   = 2;

input int  InpMaxSeconds    = 60;
input int  InpNeedTextEcho  = 1;
input int  InpNeedPongs     = 1;

WebRelay::CWebSocketClient g_ws;
CTestWsListener            g_listener;
ulong                      g_start;

int OnInit()
{
   g_ws.SetListener(g_listener);
   g_listener.Attach(g_ws);
   g_ws.SetMaxMessageSize(1<<20);
   g_ws.SetMaxCallbacksPerTick(64);
   g_ws.SetHeartbeat(true, InpHBIntervalMs, InpHBTimeoutMs, InpHBGraceMiss, InpIdleHB);

   PrintFormat("[EA] Connecting to %s:%d %s", InpHost, InpPort, InpTLS ? "(TLS)" : "");
   if(!g_ws.Connect(InpHost, (uint)InpPort, InpPath, InpTimeoutMs, InpTLS))
   {
      PrintFormat("[EA] Connect failed. LastError=%d", g_ws.LastError());
      return(INIT_FAILED);
   }

   g_start = GetTickCount64();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnTimer()
{
   for(int i=0;i<10;i++){ g_ws.Dispatch(); Sleep(10); }

   const bool time_up   = (GetTickCount64() - g_start) > (ulong)(InpMaxSeconds*1000);
   const bool goals_met = (g_listener.TextCount() >= InpNeedTextEcho && g_listener.Pongs() >= InpNeedPongs);

   if(time_up || goals_met)
   {
      PrintFormat("[EA] Stopping. text=%d bin=%d pongs=%d hb=%d errs=%d closes=%d",
         g_listener.TextCount(), g_listener.BinaryCount(), g_listener.Pongs(),
         g_listener.Heartbeats(), g_listener.Errors(), g_listener.Closes());

      g_ws.Disconnect(1000, time_up ? "timeout" : "goals met");
      const ulong t1 = GetTickCount64();
      while(GetTickCount64() - t1 < 1000) { g_ws.Dispatch(); Sleep(10); }
      ExpertRemove();
   }
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}
