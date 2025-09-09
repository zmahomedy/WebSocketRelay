//+------------------------------------------------------------------+
//| AckUtils.mqh — lightweight JSON ACK sniffer                      |
//| Looks for {"ack":"<id>", "status": <int>, "error":"<text>"}      |
//| Used by CWebSocketClient auto-ACK parsing                        |
//+------------------------------------------------------------------+
#property strict
#ifndef __WEBSOCKETRELAY_CORE_ACKUTILS_MQH__
#define __WEBSOCKETRELAY_CORE_ACKUTILS_MQH__

namespace WebSocketRelay { namespace Ack
{

// ---- Config for key names ----------------------------------------
struct AckKeys
{
   string id_key;
   string status_key;
   string error_key;

   AckKeys() { id_key="ack"; status_key="status"; error_key="error"; }
   AckKeys(const string idk,const string stk,const string erk)
   {
      id_key=idk; status_key=stk; error_key=erk;
   }
};

// ---- tiny helpers ------------------------------------------------
bool __IsSpace(const int ch)
{
   return (ch==' ' || ch=='\t' || ch=='\r' || ch=='\n');
}

// trim ASCII whitespace from both ends
string Trim(const string s)
{
   const int n = StringLen(s);
   if(n<=0) return "";
   int i=0, j=n-1;
   while(i<=j && __IsSpace(StringGetCharacter(s,i))) i++;
   while(j>=i && __IsSpace(StringGetCharacter(s,j))) j--;
   return (i<=j) ? StringSubstr(s,i,j-i+1) : "";
}

// find '"<key>"' starting at or after 'start'
int FindQuotedKey(const string src, const string key, int start=0)
{
   if(StringLen(key)==0) return -1;
   const string needle = "\""+key+"\"";
   return StringFind(src, needle, start);
}

// find the ':' that follows a key token starting at 'pos' (after the closing quote)
int NextColon(const string src, int pos)
{
   const int n = StringLen(src);
   while(pos<n)
   {
      const int ch = StringGetCharacter(src,pos);
      if(ch==':') return pos;
      if(!__IsSpace(ch)) { /* if non-space but not colon, keep scanning */ }
      pos++;
   }
   return -1;
}

// Parse a JSON string value starting right AFTER the colon.
// Supports \" escaping and \\.
bool ParseJsonStringValue(const string src, const int colon_pos, string &out)
{
   int p = colon_pos + 1;
   const int n = StringLen(src);
   while(p<n && __IsSpace(StringGetCharacter(src,p))) p++;
   if(p>=n || StringGetCharacter(src,p)!='"') return false;
   p++; // at first char of the string

   const int start = p;
   bool esc=false;
   for(int i=p;i<n;i++)
   {
      const int ch = StringGetCharacter(src,i);
      if(esc) { esc=false; continue; }
      if(ch=='\\') { esc=true; continue; }
      if(ch=='"')
      {
         out = StringSubstr(src, start, i-start);
         return true;
      }
   }
   return false; // no closing quote
}

// Parse a JSON integer value starting right AFTER the colon.
bool ParseJsonIntValue(const string src, const int colon_pos, int &out)
{
   int p = colon_pos + 1;
   const int n = StringLen(src);
   while(p<n && __IsSpace(StringGetCharacter(src,p))) p++;
   if(p>=n) return false;

   int beg = p;
   if(StringGetCharacter(src,p)=='-') p++;
   bool has_digit=false;
   while(p<n)
   {
      int ch = StringGetCharacter(src,p);
      if(ch<'0' || ch>'9') break;
      has_digit=true; p++;
   }
   if(!has_digit) return false;

   string num = StringSubstr(src, beg, p-beg);
   out = (int)StringToInteger(num);
   return true;
}

// ---- main sniffer ------------------------------------------------
// Returns true if {"<ack_key>":"id",...} was found. status/error are optional.
bool TryParseAckJson(const string src,
                     const AckKeys &keys,
                     string &ack_id,
                     int    &status,
                     string &error_text)
{
   ack_id = "";
   status = 0;
   error_text = "";

   // quick prefilter
   const int n = StringLen(src);
   if(n<6) return false;          // too small to be JSON
   if(StringFind(src,"{")<0 || StringFind(src,"}")<0) return false;

   // find "ack"
   int kpos = FindQuotedKey(src, keys.id_key, 0);
   if(kpos < 0) return false;

   // find colon after the key token
   // advance to the closing quote of "ack"
   int after_key = kpos + 2 + StringLen(keys.id_key); // " + key + "
   int colon = NextColon(src, after_key);
   if(colon < 0) return false;

   if(!ParseJsonStringValue(src, colon, ack_id)) return false;
   // status (optional)
   int spos = FindQuotedKey(src, keys.status_key, colon+1);
   if(spos >= 0)
   {
      int after_st = spos + 2 + StringLen(keys.status_key);
      int scolon = NextColon(src, after_st);
      if(scolon >= 0) ParseJsonIntValue(src, scolon, status);
   }
   // error (optional)
   int epos = FindQuotedKey(src, keys.error_key, colon+1);
   if(epos >= 0)
   {
      int after_er = epos + 2 + StringLen(keys.error_key);
      int ecolon = NextColon(src, after_er);
      if(ecolon >= 0) ParseJsonStringValue(src, ecolon, error_text);
      error_text = Trim(error_text);
   }

   return (StringLen(ack_id) > 0);
}

} } // namespace WebSocketRelay::Ack
#endif // __WEBSOCKETRELAY_CORE_ACKUTILS_MQH__