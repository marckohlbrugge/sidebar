# Armchair

A real-time AI sidebar for live podcasts by [Marc Köhlbrugge](https://x.com/marckohlbrugge).

## What is Armchair?

Armchair listens to a live YouTube stream, transcribes it in real time, and cuts in with commentary from a panel of four AI armchair critics — inspired by the staff of *The Howard Stern Show*:

- 📋 **Gary** — the stern producer who keeps facts straight
- 🎛️ **Fred** — the encyclopedic context guy with the lateral connection
- 🤣 **Jackie** — the comedy writer with the one-liner
- 🧌 **Troll** — the cynic who won't let hype slide

Each completed speaker turn is routed through a single LLM gate that casts exactly one persona (or stays silent). The result is a live "sidebar" next to the transcript: commentary arrives seconds after the point it reacts to, visually tied to the exact sentence that triggered it.

## Why this exists

Inspired by [a tweet from @twistartups](https://x.com/twistartups/status/2044437861668171974) describing exactly this idea — a live AI sidebar with four personas watching a pod in real time. It sounded like a fun thing to build, so I built it.

## Stack

- **Rails 8** — Propshaft, Importmap, Turbo Streams, Stimulus, Tailwind v4
- **SQLite** — single-file DB for the whole app (primary, Solid Queue, Solid Cable)
- **Solid Queue** — background jobs, running inside Puma via plugin
- **Solid Cable** — Turbo broadcast channel backed by the DB
- **Deepgram Nova-3** — real-time speech-to-text over WebSocket
- **RubyLLM** — thin Ruby abstraction over Anthropic's Claude (Haiku for gating, Sonnet for commentary)
- **yt-dlp + ffmpeg** — pipe live YouTube audio into Deepgram
- **Kamal** — container-based deploy

## Running locally

Requires Ruby 3.4, `yt-dlp`, `ffmpeg`, and API keys for Deepgram and Anthropic.

```bash
bin/setup

EDITOR="code --wait" bin/rails credentials:edit --environment development
# add:
#   deepgram_api_key: ...
#   anthropic_api_key: ...

bin/dev
```

Alternatively, self-hosters can set `DEEPGRAM_API_KEY` and `ANTHROPIC_API_KEY` as environment variables instead of using Rails credentials.

Visit `http://localhost:3000`, create a session with a YouTube live URL (or any recorded video), click **Start**, and watch the personas chime in.

## Status

This is an early prototype — works locally, but not yet polished for production deployment. If there's interest I'll add a proper Docker / Kamal setup and flesh out these docs with troubleshooting, tuning notes, and deployment options. Open an issue if you want to self-host and I'll prioritize it.

## How it works

1. **Ingest** — `yt-dlp --get-id` resolves the stream URL; `ffmpeg` decodes the audio to 16kHz mono PCM and pipes it into Deepgram's WebSocket.
2. **Transcript events** — raw Deepgram payloads persist immediately (`TranscriptEvent`) for replay fidelity.
3. **Turn building** — `is_final` segments accumulate until a natural sentence boundary, closing into a `Turn` of ≥8 words (80 max).
4. **Gate** — one Claude Haiku call per turn picks a persona: `wait | none | fact_checker | context | comedy | troll` with reasoning.
5. **Reaction** — the chosen persona runs a Claude Sonnet call with context from recent turns and its own recent remarks; can abstain with `PASS`.
6. **Cooldown** — a persona that just spoke is skipped for 3 turns even if re-selected.
7. **Live UI** — Turbo Streams push every turn and comment into a single CSS grid; sticky positioning keeps the latest comment pinned.

Ingest runs as a detached subprocess per session so the web stays responsive. Start/Stop buttons spawn and SIGTERM it.

## License

MIT.
