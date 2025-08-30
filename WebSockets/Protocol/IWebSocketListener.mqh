//+------------------------------------------------------------------+
//| IWebSocketListener.mqh - message-level observer                   |
//+------------------------------------------------------------------+
#ifndef __WEBRELAY_WEBSOCKETS_V2_PROTOCOL_IWEBSOCKETLISTENER_MQH__
#define __WEBRELAY_WEBSOCKETS_V2_PROTOCOL_IWEBSOCKETLISTENER_MQH__
#property strict

namespace WebRelay
{
class IWebSocketListener
{
public:
   // core
   virtual void OnOpen() {}
   virtual void OnText(const string &message) {}
   virtual void OnBinary(const uchar &data[]) {}
   virtual void OnClose(const int code,const string &reason) {}
   virtual void OnError(const int code,const string &detail) {}
   virtual void OnFatal(const int code,const string &detail) {}

   // optional telemetry
   virtual void OnPing(const string &data) {}
   virtual void OnPong(const string &data) {}
   virtual void OnHeartbeat(const int latency_ms) {}
   virtual void OnHeartbeatMiss(const int misses,const int last_seen_ms) {}

   // optional app-level ACKs (if you enable them later)
   virtual void OnAck(const ulong msg_id,const int status,const string &error_text) {}
   virtual void OnAckTimeout(const ulong msg_id,const int attempt) {}
};
} // namespace WebRelay
#endif
