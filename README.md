# CC:Tweaked Cinema thing

Modules:

- `waterframes.lua` - wrapper for the [WaterFrames Computercraft Compat](https://modrinth.com/mod/waterframes-computercraft-compat)
  peripheral (the media display)
- `jellyfin.lua` — shitty Jellyfin REST client
- `ersatz.lua` — Ersatz URL client: resolves channel from base ersatz url, displays on media display and shows xmltv EPG on create display board (CC:C Bridge)
- `displayboard.lua` — wrapper for a CC:C Bridge source block linked to a create display board
- `cinemaconfig.lua` — shared settings file

Programs (run these):

- **`cinema_sign.lua`** — main live tv program (ersatz) loads stream and egg on display board like this:
  ```
  NOW SHOWING:
  Movie (Year)
  UP NEXT:
  Movie (Year)
  ```
- **`jellyfin_client.lua`** — Custom jellyfin client for CC:Tweaked. While it's playing, `cinema_sign.lua` automatically switches the board to:
  ```
  NOW SHOWING:
  <movie or episode title>

  FROM JELLYFIN
  ```

## Setup

1. Requires: CC: Tweaked, WaterFrames + WaterFrames Computercraft Compat, Create + CC:C Bridge, and Ersatz instance already set up with a channel.
2. Wire up:
   - A computer touching (or modem-linked to) the WaterFrames frame/projector.
   - A Source Block (CC:C Bridge) nattached to that same computer, and a display link attached to the source block synced with the display board.
3. Copy all seven `.lua` files onto the computer in the same directory (or else they won't work together)
4. Run `cinema_sign.lua` for live tv or run `jellyfin_client.lua` if you want to play something manually from jellyfin.

## Notes / things to verify in-game

- **Peripheral APIs assumed:**
  - WaterFrames: `setUrl`, `getVolume`, `loop`, etc
  - CC:C Bridge Source Block: `write`, `setCursorPos`, `getSize`, `clear`, `clearLine`,and a stripped-down `term` API.
- **Board sizing:** `displayboard.lua` reads the boards size via `getSize()` and writes top down, dropping extra lines
- **EPG parsing:** `ersatz.lua` fetches `{base}/iptv/channels.m3u` to resolve your channel number to its XMLTV channel id, then `{base}/iptv/xmltv.xml` to find the current and next `<programme>` for that id, using each entry's `<title>` and `<date>`
- **Playback:** both the channel and manual Jellyfin playback use direct play (no transcoding requested)
- `cinema.cfg` stores your Jellyfin server URL/username and Ersatz base URL/channel in plaintext on the computer. Your password is NOT stored and never will be. It asks for it every time.
