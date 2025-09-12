//+------------------------------------------------------------------+
//| WRProfile.mqh — behavior presets for WebSocket client            |
//| (heartbeat, watchdog, timeouts, TX shaping, RX guards, budget).  |
//+------------------------------------------------------------------+
#property strict
#ifndef __WEBSOCKETRELAY_CORE_WRPROFILE_MQH__
#define __WEBSOCKETRELAY_CORE_WRPROFILE_MQH__

namespace WebSocketRelay
{

// ------------------------------------------------------------------
// Preset selector (keep it simple; string synonyms handled below)
// ------------------------------------------------------------------
enum WR_PROFILE_PRESET
{
   WR_PRESET_DEFAULT     = 0,
   WR_PRESET_MOBILE      = 1,
   WR_PRESET_ONSITE      = 2,   // "lan" maps here
   WR_PRESET_DATACENTER  = 3    // "dc" maps here
};

// ------------------------------------------------------------------
// Declarative knobs (bool/int only; explicit units per field)
// ------------------------------------------------------------------
struct WRProfile
{
   // ---- Heartbeat (seconds) ----
   bool hb_enable;            // enable heartbeat
   bool hb_idle_only;         // only ping when otherwise idle
   int  hb_idle_sec;          // idle window before first ping (s)
   int  hb_interval_sec;      // ping cadence while idle (s)
   int  hb_grace_misses;      // consecutive misses before degrade
   bool hb_prime_ping;        // send prime ping immediately after OPEN

   // ---- Watchdog / reconnect (milliseconds) ----
   bool wd_enable;            // auto-reconnect on failure/degraded
   int  wd_min_ms;            // min backoff (ms)
   int  wd_max_ms;            // max backoff (ms)
   int  wd_jitter_pct;        // ± jitter around backoff (percent)

   // ---- Transport timeouts & handshake caps (milliseconds/bytes) ----
   int  connect_timeout_ms;         // TCP/TLS connect slice or blocking connect
   int  handshake_timeout_ms;       // HTTP Upgrade handshake overall deadline
   int  handshake_max_header_bytes; // max header bytes to accept during handshake (slow-loris guard)

   // ---- TX shaping / fragmentation ----
   int  tx_cap_bytes;         // outbound queue cap (bytes)
   int  tx_fragment_bytes;    // socket write slice size (bytes)
   int  tx_ws_frame_bytes;    // target payload bytes per WS frame (auto-frag; 0 = lib default)
   int  frags_per_dispatch;   // max TX fragments to flush per Dispatch() tick

   // ---- Dispatch budget ----
   int  cb_max_per_dispatch;  // max callbacks delivered per Dispatch() tick

   // ---- RX safety / reassembly guards ----
   int  rx_max_message_bytes;     // hard cap for a single reassembled message
   int  rx_max_fragments;         // max fragments per message
   int  rx_reassembly_window_ms;  // time window to hold partial frames
   
   //tls
   bool force_tls_handshake_on_443; // default = false
};

// ------------------------------------------------------------------
// Small helpers
// ------------------------------------------------------------------
int WRClamp(const int v, const int lo, const int hi)
{
   return (v < lo) ? lo : ((v > hi) ? hi : v);
}

// Sanitize (clamp) a profile to safe bounds
void WRProfileSanitize(WRProfile &p)
{
   // HB
   p.hb_idle_sec      = WRClamp(p.hb_idle_sec,      1,   600);
   p.hb_interval_sec  = WRClamp(p.hb_interval_sec,  1,   120);
   p.hb_grace_misses  = WRClamp(p.hb_grace_misses,  0,   10);

   // WD
   p.wd_min_ms        = WRClamp(p.wd_min_ms,        100, 600000);
   p.wd_max_ms        = WRClamp(p.wd_max_ms,        p.wd_min_ms, 600000);
   p.wd_jitter_pct    = WRClamp(p.wd_jitter_pct,    0,   75);

   // Transport / handshake
   p.connect_timeout_ms        = WRClamp(p.connect_timeout_ms,        300, 600000);
   p.handshake_timeout_ms      = WRClamp(p.handshake_timeout_ms,      300, 600000);
   p.handshake_max_header_bytes= WRClamp(p.handshake_max_header_bytes,1024, 65536);

   // TX / fragmentation
   p.tx_cap_bytes       = WRClamp(p.tx_cap_bytes,       16*1024,     32*1024*1024);
   p.tx_fragment_bytes  = WRClamp(p.tx_fragment_bytes,  1024,        1*1024*1024);
   if(p.tx_ws_frame_bytes <= 0) p.tx_ws_frame_bytes = 16*1024; // default 16 KiB if unset
   p.tx_ws_frame_bytes  = WRClamp(p.tx_ws_frame_bytes,  1024,        1*1024*1024);
   p.frags_per_dispatch = WRClamp(p.frags_per_dispatch, 1,           64);

   // Dispatch budget
   p.cb_max_per_dispatch = WRClamp(p.cb_max_per_dispatch, 1, 1000);

   // RX caps
   p.rx_max_message_bytes    = WRClamp(p.rx_max_message_bytes,    64*1024,      64*1024*1024);
   p.rx_max_fragments        = WRClamp(p.rx_max_fragments,        1,            2048);
   p.rx_reassembly_window_ms = WRClamp(p.rx_reassembly_window_ms, 1000,         300000);
}

// ------------------------------------------------------------------
// Preset builders (each returns a sanitized profile)
// ------------------------------------------------------------------
WRProfile WRProfileDefault()
{
   WRProfile p;
   // HB
   p.hb_enable        = true;
   p.hb_idle_only     = true;
   p.hb_idle_sec      = 15;
   p.hb_interval_sec  = 5;
   p.hb_grace_misses  = 2;
   p.hb_prime_ping    = true;

   //TLS
   p.force_tls_handshake_on_443 = false;
   
   // WD
   p.wd_enable        = true;
   
   p.wd_min_ms        = 1000;
   p.wd_max_ms        = 30000;
   p.wd_jitter_pct    = 25;

   // Transport / handshake
   p.connect_timeout_ms        = 4000;
   p.handshake_timeout_ms      = 6000;
   p.handshake_max_header_bytes= 8*1024; // 8 KiB default

   // TX / fragmentation
   p.tx_cap_bytes       = 1*1024*1024;  // 1 MiB
   p.tx_fragment_bytes  = 64*1024;      // socket slice
   p.tx_ws_frame_bytes  = 16*1024;      // WS frame payload target
   p.frags_per_dispatch = 8;

   // Dispatch
   p.cb_max_per_dispatch = 128;

   // RX safety
   p.rx_max_message_bytes    = 8*1024*1024; // 8 MiB
   p.rx_max_fragments        = 128;
   p.rx_reassembly_window_ms = 30000;       // 30s

   WRProfileSanitize(p);
   return p;
}

// Mobile / constrained (conservative HB, tighter caps)
WRProfile WRProfileMobileTight()
{
   WRProfile p = WRProfileDefault();

   // Transport / handshake
   p.connect_timeout_ms        = 5000;
   p.handshake_timeout_ms      = 7000;
   p.handshake_max_header_bytes= 8*1024; // keep tight on mobile

   // TX / fragmentation
   p.tx_cap_bytes       = 512*1024;
   p.tx_fragment_bytes  = 32*1024;
   p.tx_ws_frame_bytes  = 8*1024;       // smaller frames over radio/HL links
   p.frags_per_dispatch = 6;

   // HB
   p.hb_enable        = true;
   p.hb_idle_only     = true;
   p.hb_idle_sec      = 20;
   p.hb_interval_sec  = 7;
   p.hb_grace_misses  = 2;

   // WD
   p.wd_enable      = true;
   p.wd_min_ms      = 1500;
   p.wd_max_ms      = 45000;
   p.wd_jitter_pct  = 35;

   // Dispatch
   p.cb_max_per_dispatch = 64;

   // RX (slightly tighter)
   p.rx_max_message_bytes    = 2*1024*1024; // 2 MiB
   p.rx_max_fragments        = 64;
   p.rx_reassembly_window_ms = 20000;

   WRProfileSanitize(p);
   return p;
}

// On-site / LAN (aggressive HB, larger buffers)
WRProfile WRProfileOnsiteLAN()
{
   WRProfile p = WRProfileDefault();

   // Transport / handshake
   p.connect_timeout_ms        = 2000;
   p.handshake_timeout_ms      = 3000;
   p.handshake_max_header_bytes= 16*1024; // LAN/DC can afford larger headers

   // TX / fragmentation
   p.tx_cap_bytes       = 2*1024*1024;
   p.tx_fragment_bytes  = 64*1024;
   p.tx_ws_frame_bytes  = 32*1024;      // fatter frames on LAN
   p.frags_per_dispatch = 10;

   // HB
   p.hb_enable        = true;
   p.hb_idle_only     = true;
   p.hb_idle_sec      = 12;
   p.hb_interval_sec  = 4;
   p.hb_grace_misses  = 3;

   // WD
   p.wd_enable      = true;
   p.wd_min_ms      = 800;
   p.wd_max_ms      = 15000;
   p.wd_jitter_pct  = 20;

   // Dispatch
   p.cb_max_per_dispatch = 192;

   WRProfileSanitize(p);
   return p;
}

// Low-latency datacenter (very aggressive HB, fast WD)
WRProfile WRProfileLowLatDC()
{
   WRProfile p = WRProfileDefault();

   // Transport / handshake
   p.connect_timeout_ms        = 1500;
   p.handshake_timeout_ms      = 2500;
   p.handshake_max_header_bytes= 16*1024;

   // TX / fragmentation
   p.tx_cap_bytes       = 4*1024*1024;
   p.tx_fragment_bytes  = 96*1024;
   p.tx_ws_frame_bytes  = 64*1024;      // DC pipes handle it well
   p.frags_per_dispatch = 12;

   // HB
   p.hb_enable        = true;
   p.hb_idle_only     = false;
   p.hb_idle_sec      = 10;
   p.hb_interval_sec  = 3;
   p.hb_grace_misses  = 3;

   // WD
   p.wd_enable      = true;
   p.wd_min_ms      = 500;
   p.wd_max_ms      = 10000;
   p.wd_jitter_pct  = 15;

   // Dispatch
   p.cb_max_per_dispatch = 256;

   WRProfileSanitize(p);
   return p;
}

// Alias for readability
WRProfile WRProfileDatacenter()
{
   return WRProfileLowLatDC();
}

// ------------------------------------------------------------------
// Helpers: map names <-> presets and build by preset
// ------------------------------------------------------------------
WR_PROFILE_PRESET WRNameToPreset(string name)
{
   if(StringCompare(name,"mobile",true)     == 0) return WR_PRESET_MOBILE;
   if(StringCompare(name,"onsite",true)     == 0) return WR_PRESET_ONSITE;
   if(StringCompare(name,"lan",true)        == 0) return WR_PRESET_ONSITE;
   if(StringCompare(name,"datacenter",true) == 0) return WR_PRESET_DATACENTER;
   if(StringCompare(name,"dc",true)         == 0) return WR_PRESET_DATACENTER;
   return WR_PRESET_DEFAULT;
}

string WRPresetToName(const WR_PROFILE_PRESET p)
{
   switch(p)
   {
      case WR_PRESET_MOBILE:      return "mobile";
      case WR_PRESET_ONSITE:      return "onsite";
      case WR_PRESET_DATACENTER:  return "datacenter";
      default:                    return "default";
   }
}

WRProfile WRBuildProfileForPreset(const WR_PROFILE_PRESET p)
{
   switch(p)
   {
      case WR_PRESET_MOBILE:      return WRProfileMobileTight();
      case WR_PRESET_ONSITE:      return WRProfileOnsiteLAN();
      case WR_PRESET_DATACENTER:  return WRProfileDatacenter();
      default:                    return WRProfileDefault();
   }
}

} // namespace WebSocketRelay
#endif // __WEBSOCKETRELAY_CORE_WRPROFILE_MQH__