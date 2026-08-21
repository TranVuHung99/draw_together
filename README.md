# Draw Together

A real-time collaborative drawing mini-game inspired by r/place. Instead of placing pixels, every
player gets their own rectangular slice of a shared canvas and draws freely inside it. When the
timer runs out the regions become one composite picture.

- A player creates a room and becomes the **host**; others join with a six-character room code.
- Starting the game partitions the canvas into a grid and assigns each drawing player one region.
- The host observes the whole canvas live and does not draw.
- Strokes sync in real time, incrementally — the canvas is never resent wholesale.
- When the server's deadline passes, drawing locks and everyone receives the final artwork.

## Stack

| | |
|---|---|
| Client | Flutter (web-first, mobile supported), Riverpod for state |
| Server | Serverpod 3.3.1 |
| Database | PostgreSQL, through Serverpod models and migrations |
| Realtime | Serverpod streaming endpoint over WebSocket, with a pub/sub channel per room |

No Firebase, no third-party realtime service.

## Layout

```
draw_together_flutter/                    the game client
  lib/models/                             canvas viewport, stroke, per-player stroke board
  lib/providers/                          Riverpod state; websocket_service.dart is the socket bridge
  lib/ui/                                 screens and the canvas widgets
draw_together_serverpod/
  draw_together_serverpod_server/         the server
    lib/src/models/*.spy.yaml             model definitions; `serverpod generate` builds from these
    lib/src/endpoints/                    room endpoint + the streaming endpoint
    lib/src/composition/canvas_svg.dart   builds the final composite as SVG
    lib/src/future_calls/                 the server-owned game deadline
    migrations/                           generated SQL migrations
  draw_together_serverpod_client/         generated client package, consumed by the Flutter app
implement.md                              the original brief
```

## How it fits together

**Everything is normalized.** Points, regions, and stroke widths are fractions of the canvas in the
range 0.0–1.0, never widget pixels. A stroke means the same thing on a phone, on a wide browser
window, in the server's SVG, and in an exported PNG. Clients convert to and from local pixels only
at the edges, which is what keeps two players' screens showing the same artwork at different sizes.

**One viewport per view.** Every canvas view is a rect of normalized space mapped onto the widget
area: the whole canvas `(0, 0, 1, 1)` for the host and for a spectating player, the player's own
region in draw mode. The viewport is letterboxed rather than stretched, so a circle drawn in draw
mode is still a circle on the full-canvas view.

**One layer per drawing player.** Strokes are grouped by owner, painted into a layer clipped to that
owner's region, and composited in ascending player id order. That grouping is what confines the
eraser to its owner's own work instead of punching through a neighbour's. Composition happens in
canvas space and the result is mapped through the viewport afterwards, so draw mode and the
full-canvas view are the same image at different magnifications.

**The server owns the truth.** Completed strokes are persisted one row each and replayed to any
client that subscribes, so the canvas survives a disconnect — including the host's. Undo is a
server-verified deletion of the player's own most recent stroke, broadcast to everyone including
the requester. The end of the game is a scheduled server-side future call: it flips the room to
`FINISHED`, generates the composite, and broadcasts it. Client countdowns are display-only.

**The final artifact is an SVG.** The stroke model maps onto SVG one-to-one, so the server builds
the composite as a string — one `<g clip-path>` per player, a `<polyline>` per stroke, a `<mask>`
per eraser — in a unit `viewBox`. Clients render it with Skia; PNG export is an explicit action that
rasterizes locally at the room's configured resolution, so nobody pays for a raster nobody asked
for.

## Running it

Start the databases (Postgres for development on 8090, and a test instance on 9090):

```bash
cd draw_together_serverpod/draw_together_serverpod_server
docker compose up -d
```

Run the server — it serves the API on 8080, Insights on 8081, and the web server on 8082:

```bash
dart bin/main.dart --apply-migrations
```

Run the client. It points at `http://localhost:8080/` (see
`draw_together_flutter/lib/core/serverpod_client.dart`; use `http://10.0.2.2:8080/` for an Android
emulator):

```bash
cd draw_together_flutter
flutter run -d chrome
```

To play, open several browser windows: create a room in one, join it by code from the others, then
start the game from the host window. The host observes; everyone else draws.

### After changing a model or an endpoint

Model definitions live in `lib/src/models/*.spy.yaml`. Regenerate the protocol and the client
package, and create a migration if the schema changed:

```bash
cd draw_together_serverpod/draw_together_serverpod_server
serverpod generate
serverpod create-migration        # only when a table or column changed
dart bin/main.dart --role maintenance --apply-migrations
```

### Tests

Integration tests run against the test database on port 9090 and cover stroke persistence, replay,
undo ownership rules, the room state machine, and SVG generation:

```bash
cd draw_together_serverpod/draw_together_serverpod_server
dart bin/main.dart --mode test --role maintenance --apply-migrations   # first run only
dart test
```

## Known gaps

Deliberately out of scope for a playable core, and worth knowing before extending it:

- **No reconnect after a page refresh.** The server replays a room's strokes to any client that
  subscribes, but the client keeps no record of which room and player it was, so refreshing a tab
  returns to the lobby with no way back in.
- **No authentication or host authorization.** `startGame` is callable by anyone who knows the room
  id.
- **Room codes can collide.** They are random and never checked for uniqueness.
- **Single server only.** Room fan-out uses Serverpod's in-process message central; multi-server
  operation would need Redis.
- **No redo**, and undo is a hard delete with no recovery.
