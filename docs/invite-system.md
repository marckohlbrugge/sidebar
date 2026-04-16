# Invite System — Plan

Goal: let people try Armchair via a shared link without an account system, without runaway API costs if the link leaks beyond the intended group (an X group Marc plans to post in).

## What exists today

- `/manage/*` is HTTP-basic-auth-gated (Rails credentials `manage.username` / `manage.password`) via `Manage::BaseController`. Creates sessions, no caps.
- Public `/sessions/:token` is unauthenticated viewing only (read-only, uses `StreamSession#token` via `has_secure_token`).
- Session-wide LLM call cap lives in `AnalyzeTurnJob::LLM_CALL_CAP` (500). Both `AnalyzeTurnJob` and `PersonaReactionJob` check it.
- `StreamSession#source_kind` is either `:url` (ffmpeg subprocess) or `:microphone` (browser WS → Deepgram).
- Mic ingest happens in-process inside `StreamSession::BrowserIngest`, which owns both the browser WS and the Deepgram WS.

## The invite model

New model `Invite`:

| field                           | type    | default | notes                                                     |
| ------------------------------- | ------- | ------- | --------------------------------------------------------- |
| `code`                          | string  |         | `has_secure_token :code` — unguessable, indexed unique    |
| `label`                         | string  |         | internal note: "x-group-drop-2026-04-16", "marc's mom", … |
| `max_sessions`                  | integer | 5       | how many sessions this code can create in total           |
| `sessions_used`                 | integer | 0       | counter, bumped on session create                         |
| `max_turns_per_session`         | integer | 50      | caps transcript length (~10 min of continuous speech)     |
| `max_llm_calls_per_session`     | integer | 20      | per-invite override of `AnalyzeTurnJob::LLM_CALL_CAP`     |
| `revoked_at`                    | datetime| nil     | null invite to kill URL without deleting history          |

`StreamSession` gets `belongs_to :invite, optional: true` so manage-created sessions (no invite) keep the existing unlimited behavior.

## Flow

1. Marc creates an invite in `/manage/invites` (new CRUD under the existing manage auth), copies the URL.
2. User visits `https://armchair.marc.io/i/<code>`. A new `InvitesController#show` (or redirect action) looks up the invite, drops a **signed cookie** `invite_id=<id>` (or just stash `invite_code` — signed, read-only on the server), then redirects to either a dedicated invite-landing page or the public root with a "Start session" CTA.
3. The invited user creates sessions via a new non-manage route (e.g. `POST /sessions` gated by the cookie). Controller:
   - Loads invite from cookie; 404 if missing/revoked.
   - Refuses if `invite.sessions_used >= invite.max_sessions`.
   - Creates session with `invite_id: invite.id` and `source_kind: :microphone` (mic-only for invites feels right — URL mode lets users point at arbitrary streams, which is harder to cost-control).
   - Atomically increments `invite.sessions_used`.
4. User lands on `/sessions/<token>` with the same public show page they see today, plus the mic-recorder controller.
5. When they stop or hit a cap, session ends.

## Enforcement points

Existing caps become "use invite-scoped limits when a session has an invite":

```ruby
# AnalyzeTurnJob
cap = session.invite&.max_llm_calls_per_session || AnalyzeTurnJob::LLM_CALL_CAP
return if session.llm_call_count >= cap

# same in PersonaReactionJob
```

New turn-count cap (enforced in `AnalyzeTurnJob` so it runs at gate time):

```ruby
turn_cap = session.invite&.max_turns_per_session
return if turn_cap && session.turns.count >= turn_cap
```

**Hard stop on further Deepgram audio** once the turn cap is reached. Without this, an invited user could keep talking with no comments but still burn Deepgram minutes. In `BrowserIngest` / `TurnBuilder`, after a turn closes, check `invite.max_turns_per_session` and if reached, send `CloseStream` to Deepgram + close the browser WS. Display "Session limit reached" on the client.

Optional hard time cap (probably skip for v1): `max_audio_seconds` on the invite, compared against `turns.last.audio_end_ms`.

## URL shape

- `GET /i/:code` — `InvitesController#show`, drops cookie, redirects to `/sessions/new` (public) or wherever the invite-landing page ends up.
- `GET /sessions/new` — invite-gated new form. Today this is only under `/manage/sessions/new`.
- `POST /sessions` — invite-gated create. Today this is only `/manage/sessions#create`.
- `GET /sessions/:token` — unchanged, public viewing.
- `GET /sessions/:token/ingest` — unchanged, mic WebSocket.
- `GET /manage/invites`, `/manage/invites/new`, `/manage/invites/:id` — admin CRUD for invites.

Controller structure: reuse an `Invited::` concern or `Invited::StreamSessionsController` that inherits `ApplicationController` (no HTTP basic auth) but has a `before_action :require_invite!`.

## Manage side stays untouched

- `/manage/*` keeps HTTP basic auth, no invite involvement.
- Marc-created sessions have `invite_id: nil` and keep today's unlimited behavior.
- Invites CRUD lives under `/manage/invites` for Marc's own use.

## Skipping for v1

- Per-user tracking within an invite (if two friends share the link, they share the same cap pool — that's fine).
- Time-based invite expiry (burn-based is enough; `revoked_at` is the kill switch).
- Rate limiting beyond caps.
- Tracking which session was created by which browser session (cookie-based anonymity is fine).
- URL-mode sessions for invited users (mic-only keeps cost predictable).

## Rough cost ceiling per fully-burned invite

5 sessions × 50 turns × (average 1 persona call per turn, not all turns trigger) × ~$0.01/call + Deepgram at ~$0.01/minute × ~50 minutes ≈ **under $5 per burned invite**. Marc decides how many to drop.

## Code pointers for the fresh session

- Existing session creation: `app/controllers/manage/stream_sessions_controller.rb#create` — copy the `@session.spawn_ingest! if @session.source_url?` pattern.
- Session model: `app/models/stream_session.rb` — add `belongs_to :invite, optional: true`.
- Cap enforcement examples:
  - `app/jobs/analyze_turn_job.rb` — constant `LLM_CALL_CAP`, kill-switch + cap checks.
  - `app/jobs/persona_reaction_job.rb` — same cap check.
- Mic session hard stop: `app/models/stream_session/browser_ingest.rb` — `#cleanup` is where to force a close when caps hit; add a check after each `@turns.handle(...)` call, or inside `TurnBuilder#close!` after persisting.
- Cookie signing: `cookies.signed[:invite_id]` — Rails built-in. Works without extra config.
- Invite token: `has_secure_token :code` — same pattern `StreamSession` already uses.

## Deferred decisions (ask Marc before coding)

- Exact cap numbers (my defaults above are a starting point).
- Whether invites can be used for URL-mode or just mic (I'd say mic-only v1).
- Landing page copy for `/i/:code` — a minimal explanatory page vs straight redirect.
- What users see when they hit a cap mid-recording (toast, banner, hard redirect).
