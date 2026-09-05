# CC:Tweaked Cinema — WaterFrames + Jellyfin + ErsatzTV + Display Board

Modules:

- `waterframes.lua` — wrapper for the [WaterFrames Computercraft Compat](https://modrinth.com/mod/waterframes-computercraft-compat)
  peripheral (the projector): setUrl/getUrl, play/pause/stop, volume, transparency, loop, tick/seek.
- `jellyfin.lua` — minimal Jellyfin REST client: login, list/search movies, list series/seasons/episodes, build a direct-play stream URL.
- `ersatz.lua` — minimal ErsatzTV client: resolves a channel's stream URL, and reads its XMLTV guide to work out what's on now / up next.
- `displayboard.lua` — wrapper for a **CC:C Bridge Source Block** linked to a Create Display Board (the departure-board sign).
- `cinemaconfig.lua` — tiny shared settings file so the two programs below don't clobber each other's config.

Programs (run these):

- **`cinema_sign.lua`** — the main show. Loads your Ersatz channel onto the projector (looped), and keeps the display board showing:
  ```
  NOW SHOWING:
  Movie (Year)
  UP NEXT:
  Movie (Year)
  ```
  pulled live from Ersatz's own EPG. Run this continuously (its own multishell tab, or as the computer's `startup.lua`).
- **`jellyfin_client.lua`** — the manual/backup player. Browse or search Movies, or drill into TV Shows → Seasons → Episodes, and play something directly on the projector, overriding the channel. While it's playing, `cinema_sign.lua` automatically switches the board to:
  ```
  NOW SHOWING:
  <movie or episode title>

  FROM JELLYFIN
  ```
  Choose **"Return to Channel"** in the menu to clear the override and go back to the normal Ersatz channel + EPG board.

## How the two programs talk to each other

They don't talk directly — `jellyfin_client.lua` just writes a small state file (`cinema_override.txt`) when it starts playing something, and deletes it when you choose "Return to Channel". `cinema_sign.lua` polls for that file every 15 seconds (`POLL_SECONDS` in the script) and switches its display accordingly. Both read/write `cinema.cfg` for shared settings (Jellyfin server, Ersatz base URL/channel) — your Jellyfin password is never saved.

Run both on the **same computer** (the one wired to both the WaterFrames projector and the Source Block), in separate multishell tabs on an Advanced Computer, since they need to run at the same time.

## Setup

1. Requires: **CC: Tweaked**, **WaterFrames** + **WaterFrames Computercraft Compat**, **Create** + **CC:C Bridge**, and your **ErsatzTV** instance already set up with a channel.
2. Wire up:
   - A computer touching (or modem-linked to) the WaterFrames frame/projector.
   - A **Source Block** (CC:C Bridge) near/attached to that same computer, tuned via Create's Display Link frequency system to a **Target Block** near your physical Display Board.
3. Copy all seven `.lua` files onto the computer, same directory.
4. Run `cinema_sign.lua` first (sets up the projector + board and starts looping the channel). Run `jellyfin_client.lua` whenever you want to manually play something instead.

## Notes / things to verify in-game

- **Peripheral APIs assumed:**
  - WaterFrames: `setUrl`, `getVolume`, `loop`, etc. — from the mod's published API description.
  - CC:C Bridge Source Block: `write`, `setCursorPos`, `getSize`, `clear`, `clearLine` — a stripped-down `term` API, per the [Source Block wiki page](https://github.com/tweaked-programs/cccbridge/wiki/Source-Block).
  Run `peripheral.call(<name>, "getMethods")` on each in-game to confirm; tweak the two wrapper files if anything's named differently in your mod versions.
- **Board sizing:** `displayboard.lua` reads the board's actual size via `getSize()` and writes top-down, dropping extra lines / leaving spares blank — so a "2x6" board (which should report 6 rows) comfortably fits the 4-line NOW SHOWING/UP NEXT layout with room to spare.
- **EPG parsing:** `ersatz.lua` fetches `{base}/iptv/channels.m3u` to resolve your channel number to its XMLTV channel id, then `{base}/iptv/xmltv.xml` to find the current/next `<programme>` for that id, using each entry's `<title>` and `<date>` (release year, when Ersatz includes it — e.g. from Jellyfin metadata). No local/LAN allowlist issues for you since Ersatz is behind your Cloudflare tunnel.
- **Playback:** both the channel and manual Jellyfin playback use direct play (no transcoding requested) — WaterFrames' own media backend needs to be able to decode the source file/stream.
- `cinema.cfg` stores your Jellyfin server URL/username and Ersatz base URL/channel in plaintext on the computer (not your password). Treat access to the computer accordingly.
