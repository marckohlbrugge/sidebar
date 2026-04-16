# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

Armchair listens to a live or recorded YouTube stream, transcribes it with Deepgram Nova-3, and interleaves commentary from four LLM personas (Gary the producer, Fred the context guy, Jackie the comedy writer, Troll the cynic) next to the transcript. See `README.md` and `docs/prd.md` for product context.

## Running locally

```bash
bin/dev                                 # Puma + Tailwind watch + Solid Queue (all via the puma plugin)
bin/rails runner script/ingest.rb <id>  # Runs ingest against a StreamSession id — normally spawned by the app, handy for debugging
```

Credentials live in `config/credentials.yml.enc` (dev and prod). Either edit them with `EDITOR="…" bin/rails credentials:edit` or set `DEEPGRAM_API_KEY` / `ANTHROPIC_API_KEY` environment variables. In production, `manage.username` + `manage.password` gate the `/manage/*` routes via HTTP basic auth — without them set, prod admin refuses everyone.

External binaries required on PATH: `yt-dlp` and `ffmpeg`. The production Dockerfile installs both.

No tests in this repo yet.

## Architecture

### The pipeline (ingest → turns → gate → persona)

1. **`StreamSession::Spawner#spawn!`** — the only thing that runs in the web request. Just does `Process.spawn` with `pgroup: true` and `/dev/null` stdin, records the pid. Do **not** add yt-dlp calls here; they're slow enough to time out the request.
2. **`script/ingest.rb`** — entry point for the spawned subprocess. Calls `StreamSession::Ingest#run`.
3. **`StreamSession::Ingest#run`** — detects live vs recorded via `YtDlp.live?`, resolves video id + stream URL, opens a Deepgram WebSocket (`faye-websocket` + `EventMachine`), pipes `ffmpeg` output into it. Uses `-re` for live sources (real-time pacing) and no `-re` for recorded (as-fast-as-possible). Every Deepgram frame is persisted via `TranscriptEvent.from_deepgram` and accumulated into the current turn buffer.
4. **Turn building** — turn closes when the buffer has ≥ `MIN_WORDS_PER_TURN` words and Deepgram's `speech_final` fires, or when it hits `MAX_WORDS_PER_TURN`. `Turn#audio_start_ms` / `audio_end_ms` come from Deepgram's `start`/`duration` fields so replay can sync to video playback time.
5. **`Turn#after_create_commit` → `AnalyzeTurnJob`** — runs the gatekeeper, which is one Claude Haiku call. The gate's `action` is directly the persona key (`wait | none | fact_checker | context | comedy | troll`), so there's no separate router — the LLM casts the scene.
6. **`AnalyzeTurnJob`** — enqueues `PersonaReactionJob` for the chosen persona (skipping if the persona just spoke in the last 3 turns, or if session is kill-switched, or over the 500-call cap). Each `Turn::Persona::*` subclass carries its prompt/model/color via `class_attribute`.
7. **`Comment#broadcasts_to`** — appends to the `:timeline` Turbo stream. The persona's bg classes ride on the comment's `data-highlight-classes` so the front-end can paint the paired turn without the server needing to re-broadcast it.

### Public vs Manage

- **Public** (`StreamSessionsController#show`): read-only, no controls beyond REPLAY. Looks up sessions by `has_secure_token`-generated `token` — URLs are `/sessions/XyZ...`, never `/sessions/17`.
- **Manage** (`Manage::*Controller`): index/new/create + `Ingest#destroy` (stop) + `Demo#create`/`#destroy` (toggle the demo flag that surfaces a session on the home page). All inherit from `Manage::BaseController`, which gates the namespace with `http_basic_authenticate_with` in production only.

### Stimulus controllers and replay

The replay feature has two modes that live in `replay_controller.js`:

- **Video-driven** — when a `data-replay-target="video"` element is present. Creates a `YT.Player`, waits for `PLAYING`, then polls `getCurrentTime()` every 200ms and toggles `.hidden` on items whose `data-show-at-ms` has passed. Seeking in the video just means the next tick recomputes visibility.
- **Timer-driven** — fallback when no video target is rendered. Reveals each item on `setTimeout`, with gaps clamped between 300ms and 4s so dead air doesn't drag.

The `replay-pending` class on `#timeline` hides every item server-side until the controller takes over — prevents a FOUC flash on `?replay=1` deep links.

`highlighter_controller.js` does **only** `childList` mutation watching (no `attributeFilter: ["class"]` — that used to feedback-loop with replay's `.hidden` toggles and froze the tab). It catches live Turbo appends and paints the paired turn; replay manages highlights directly in its own reveal/hide flow.

`autoscroll_controller.js` listens to `turbo:before-stream-render` to remember scroll position, then either pins to bottom or shows a `↓ NEW` badge depending on whether the user is near the bottom. The scroll itself is coalesced into a 120ms throttle so rapid appends don't stutter.

`draggable_controller.js` lets the floating video be dragged around and snaps to the nearest viewport corner on release. Distinguishes drag from click via a 5px threshold so `<summary>` still toggles the minimize state. Persists the chosen corner in localStorage.

### Database

Single SQLite file. Solid Queue, Solid Cable, and the primary app all share the same DB — the Solid Cable adapter points at `primary` in `config/cable.yml`. This matters because the detached ingest subprocess and the Puma process share a DB, which is how broadcasts cross process boundaries.

### Things that look weird but aren't

- **DHH-style controllers/models**: `broadcasts_to` macros, `has_secure_token`, class_attribute-driven personas, `Manage::StreamSessionScoped` concern. If you catch yourself writing a service object, extract a PORO under the model namespace instead (see `StreamSession::Ingest`, `StreamSession::Spawner`, `Turn::Gatekeeper`).
- **Session identifier**: `to_param` returns the token, so any call site doing `find(params[:id])` must use `find_by!(token: params[:id])`. The only place that still takes an integer is `script/ingest.rb`, which is only ever invoked by Spawner with the canonical id.
- **Gate action strings and persona keys are the same vocabulary**: `GateDecision::ACTIONS` + `Turn::Persona::<Name>.key`. A gate action of `comedy` maps directly to `Turn::Persona::Comedy`. Don't introduce a translation layer.
- **LLM call cap + kill switch** live in `AnalyzeTurnJob::LLM_CALL_CAP` and `StreamSession.kill_switched?` (class method reading `ENV["KILL_SWITCH"]`). Both jobs check these up front.
