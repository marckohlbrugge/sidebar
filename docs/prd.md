# PRD: Real-Time YouTube Stream Transcription, Commentary, and Fact-Checking System

## 1. Summary

Build a Rails-based system that ingests live audio from a YouTube stream, transcribes it in real time, detects when a speaker has completed a meaningful point, and then routes that point into one or more AI agents for commentary and/or fact-checking.

The system should be optimized for low latency, high observability, and strong developer ergonomics. It should support both live operation and replay-based development from captured transcript events.

The implementation should use:

* Ruby on Rails as the application framework
* RubyLLM as the LLM abstraction layer
* Deepgram Nova-3 as the primary real-time transcription provider

The system should not rely on a single giant conversation prompt. It should instead use a pipeline of small, focused steps with structured outputs.

---

## 2. Goals

### Primary goals

* Transcribe a live YouTube stream in real time
* Convert streaming transcript snippets into coherent turns or utterances
* Decide whether the latest speech is complete enough to react to
* Extract factual claims when appropriate
* Generate AI commentary in near real time
* Support multiple commentary personalities
* Support replay-based testing and debugging from stored transcript event data
* Make it easy to inspect, debug, and iterate on the pipeline inside a Rails app

### Secondary goals

* Support future expansion to multiple transcription providers
* Support future expansion to multiple fact-checking backends and retrieval tools
* Support future ranking and selection between several AI personalities
* Support future overlays, dashboards, clips, and social content generation

---

## 2a. Scope note

This is a hackathon-style prototype, ~1 hour of build time. Decisions baked into the PRD so the implementer doesn't re-think them:

* **Stack:** Rails 8, Solid Queue for jobs, Turbo Streams for the live debug UI, SQLite in dev, Postgres in prod.
* **Audio:** `yt-dlp | ffmpeg` piped to Deepgram Nova-3 WebSocket.
* **Turn close:** Deepgram `speech_final`.
* **Models:** `claude-haiku-4-5` for gate + claim extraction, `claude-sonnet-4-5` for personality commentary.
* **Personality:** one agent, dry skeptical analyst.
* **LLM cache:** DB-backed, keyed on `(stage, model, prompt_hash)`.
* **Deploy:** Kamal, single container with yt-dlp + ffmpeg installed.

Skip for v1: diarization, fact-check pipeline, multiple personalities, scheduler ranking beyond cooldown, speed controls in replay.

## 3. Non-goals

These are explicitly out of scope for the first version:

* Building a perfect fact-checking system with guaranteed truthfulness
* Handling every possible live video source beyond YouTube
* Full multi-user SaaS support
* Billing, user accounts, and permissions beyond minimal internal admin use
* Advanced speaker diarization as a hard requirement
* Fully autonomous publishing of comments to public platforms
* A polished public-facing UI

---

## 4. Product vision

The system acts like a real-time AI co-host.

It listens to a live stream, understands what is being said, determines whether the speaker has finished making a point, and only then decides whether to:

* wait for more
* ignore the point
* comment on it
* fact-check it

Long term, the system should support multiple AI personalities with different styles such as skeptical, deadpan, enthusiastic, contrarian, or analyst. These personalities should react to a shared structured interpretation of the transcript rather than each independently reading noisy raw transcript snippets.

---

## 5. Core product principles

1. **Turns over tokens**
   The system should reason over completed speech turns or utterances, not arbitrary last-N-word windows.

2. **Structured outputs over freeform prompting**
   Each LLM step should return structured data whenever possible.

3. **One brain, many mouths**
   A neutral understanding layer should interpret the transcript first. Personality agents should consume normalized events, not raw streaming text.

4. **Replayable development**
   The system should be easy to develop and debug without requiring a live YouTube stream every time.

5. **Fast but cautious**
   The system should support low-latency reactions, but avoid reacting to half-finished thoughts or unstable interim transcript text.

6. **Observable by default**
   Every stage should be inspectable in the database and debug UI.

---

## 6. User stories

### Primary internal user story

As the operator, I want to point the system at a live stream and watch transcript, claims, and AI reactions appear in real time so that I can validate the system and eventually turn it into a live commentary/fact-check experience.

### Development user stories

* As the developer, I want to replay a captured transcript session so I can iterate without needing the stream to be live.
* As the developer, I want to inspect every event, turn, LLM decision, and comment so I can debug why the system reacted or stayed silent.
* As the developer, I want to compare different prompts, models, and personalities on the same input fixture.

### Future operator stories

* As the operator, I want to enable or disable certain personalities.
* As the operator, I want to tune thresholds for when the system reacts.
* As the operator, I want to see a feed of fact-check-worthy claims.

---

## 7. High-level system architecture

The system should be built as a pipeline with clear stages:

1. **Ingestion layer**
   Receives audio from a YouTube stream and sends it to Deepgram for real-time transcription.

2. **Transcript event capture layer**
   Stores the raw transcription provider events as they arrive.

3. **Turn builder layer**
   Converts interim and final transcript snippets into coherent turns or utterances.

4. **Understanding layer**
   Uses an LLM to determine whether the latest turn is complete and whether it should be ignored, commented on, or fact-checked.

5. **Claim extraction layer**
   Extracts factual claims from turns that appear fact-check-worthy.

6. **Fact-check layer**
   Verifies extracted claims using retrieval and/or external data sources.

7. **Personality commentary layer**
   Generates commentary from one or more AI personalities based on normalized events.

8. **Scheduler/ranker layer**
   Decides whether any personality should speak and, if so, which one.

9. **Presentation/debug layer**
   Displays transcript, decisions, claims, commentary, and state in a Rails admin/debug UI.

10. **Replay/testing layer**
    Replays stored transcript event sessions to reproduce behavior deterministically.

---

## 8. Recommended data flow

### Live mode

1. Obtain audio from a YouTube live stream
2. Send audio to Deepgram Nova-3
3. Receive streaming transcript events
4. Persist raw events immediately
5. Update current turn based on interim and final transcript updates
6. When a turn is complete, enqueue analysis jobs
7. Run gatekeeper decision step
8. Depending on the decision:

   * wait
   * ignore
   * extract claims and fact-check
   * generate commentary
9. Persist all outputs
10. Broadcast results to the internal UI and any future overlay/output channel

### Replay mode

1. Load a previously captured transcript event fixture
2. Re-feed those events into the same turn-building pipeline
3. Run the same downstream analysis and scheduling logic
4. Compare outputs against expected behavior or inspect manually

---

## 9. Functional requirements

### 9.1 Transcription ingestion

The system must:

* support streaming audio transcription via Deepgram Nova-3
* persist raw provider events exactly as received
* distinguish between interim and final transcript events
* preserve timing metadata where available
* support future replacement or addition of transcription providers

The system should:

* keep the provider-specific ingestion code isolated from the rest of the app
* normalize provider events into an internal representation where helpful

### 9.1.1 YouTube audio extraction

Use `yt-dlp` to pull the live audio stream and pipe it through `ffmpeg` to Deepgram's WebSocket endpoint. Both tools are installed in the Docker image deployed via Kamal. No need to over-engineer reconnection logic in the prototype — if the pipe dies, the operator can restart the session.

### 9.2 Raw transcript event storage

The system must:

* store the raw transcript events from the provider
* preserve ordering
* preserve enough metadata to replay the stream later
* make raw events inspectable in a debug UI

The stored event data should be sufficient to reconstruct:

* interim churn
* finalization timing
* pauses or utterance boundaries
* segmentation behavior

### 9.3 Turn builder

The system must:

* maintain a current in-progress turn
* update that turn as interim transcript events arrive
* finalize and close a turn when enough evidence exists that the speaker has completed a thought
* persist finalized turns for downstream analysis

**Prototype rule:** close a turn on Deepgram's `speech_final=true`. Concatenate `is_final` segments into the current turn until `speech_final` arrives, then flush. Ignore speaker diarization for v1.

### 9.4 Understanding / gatekeeper agent

The system must run a neutral decision layer after a turn closes.

This layer must classify the latest turn into one of:

* WAIT
* IGNORE
* COMMENT
* FACT_CHECK

It should also estimate:

* whether the thought appears complete
* how important it is
* how novel it is
* whether the turn contains a fact-check-worthy claim

This step should use RubyLLM with structured output.

**Prototype model:** `claude-haiku-4-5` for gate decisions. Fast, cheap, good enough.

### 9.5 Claim extraction

When the gatekeeper identifies a turn as fact-check-worthy, the system must extract one or more structured claims.

Each claim should capture, where possible:

* subject
* predicate
* object/value
* time reference
* quote or supporting text
* confidence
* whether the claim is actually checkable

The claim extraction step should also use RubyLLM with structured output. Prototype model: `claude-haiku-4-5`.

### 9.6 Fact-check pipeline

The system must support a fact-check workflow for extracted claims.

The first version may use a simple retrieval and analysis approach, but the architecture should anticipate:

* web search or external retrieval tools
* cached facts
* multiple verification passes
* confidence scoring
* citation generation

The system should support a fast speculative pass and a slower confirmation pass.

### 9.7 Personality commentary

The system must support at least one AI personality in the first version and should be designed to support many.

**Prototype personality:** a dry, skeptical analyst. One personality only, using `claude-sonnet-4-5`.

Personality agents should:

* consume normalized events rather than raw transcript snippets
* generate concise commentary
* be able to decline to comment
* avoid repeating recent observations

Examples of future personalities:

* skeptic
* hype commentator
* deadpan observer
* analytical explainer
* contrarian

Each personality should be configurable independently.

### 9.8 Scheduling and selection

The system must not let every personality comment on every turn.

The scheduler should:

* respect cooldowns per personality
* rank or filter candidate comments
* suppress low-confidence or repetitive comments
* allow the system to remain silent when nothing worth saying exists

The initial version can be simple but should have a clear extension path.

### 9.9 Rolling context and memory

The system should maintain multiple levels of context:

* current in-progress turn
* recent finalized turns
* rolling summary of recent discussion
* recent claims
* recent emitted comments

This rolling state should help agents stay coherent without requiring massive prompts.

The rolling summary may be updated periodically rather than on every transcript event.

### 9.10 Internal debug UI

The system must include an internal UI that shows at least:

* raw transcript events
* current in-progress turn
* finalized turns
* gatekeeper outputs
* extracted claims
* fact-check results
* personality outputs
* which comment, if any, was selected

The UI should support replay inspection and make it easy to understand why a reaction happened.

### 9.11 Replay mode

The system must support replaying previously captured transcript event sessions.

Replay mode should support:

* normal speed
* accelerated speed
* pausing
* stepping through events
* stepping through finalized turns

Replay mode should run through the same logic used in live mode as much as possible. Because LLMs are nondeterministic, replay determinism for agent outputs relies on the cache in §9.12 — cache hits reproduce prior outputs; cache misses re-invoke the model.

### 9.12 Caching and deterministic development

The system should support caching LLM outputs during development so that replaying the same transcript does not always require fresh model calls.

It should be possible to:

* run using live LLM calls
* run using cached LLM calls
* selectively invalidate cache for a particular stage

---

## 10. Non-functional requirements

### Performance

* Live transcript processing should feel near real time
* Commentary should typically appear soon after a turn completes
* The system should avoid blocking the main ingestion pipeline on slow downstream work

### Reliability

* Raw transcript events must be stored before downstream processing whenever possible
* Jobs should be resilient to transient provider or LLM failures
* Reprocessing a turn should be possible

### Observability

* Every major step should be persisted or logged in a way that can be inspected later
* It should be easy to understand why a turn resulted in WAIT, IGNORE, COMMENT, or FACT_CHECK

### Modularity

* The pipeline should be composed of replaceable services
* Provider-specific logic should be isolated
* Prompt-specific logic should be isolated

### Cost control

* Avoid sending every interim transcript snippet to LLMs
* Prefer analysis on finalized or nearly-finalized turns
* Use smaller/faster models for gating and extraction when appropriate
* Support development-time caching
* Kill switch: a `KILL_SWITCH=1` env var and an admin button that halts ingestion and LLM calls
* Hard ceiling of 500 LLM calls per session; top up provider accounts with small balances as a second line of defense

---

## 11. Suggested domain concepts and entities

The exact schema is up to implementation, but the system should likely model concepts such as:

* stream session
* transcript raw event
* transcript turn
* rolling summary
* gate decision
* extracted claim
* fact-check result
* personality response
* selected comment/output
* replay fixture or transcript fixture

The underlying design should preserve a clear audit trail from:
raw event -> turn -> gate decision -> claim extraction -> fact-check/commentary -> selected output

---

## 12. Agent architecture

### Agent roles

The system should treat agents as focused roles rather than one giant chatbot.

Recommended agent categories:

#### Gatekeeper agent

Purpose:

* decide whether the latest turn is complete enough and important enough to react to

Output:

* structured decision such as WAIT / IGNORE / COMMENT / FACT_CHECK

#### Claim extraction agent

Purpose:

* convert fact-check-worthy turns into atomic claims

Output:

* structured claims with confidence and checkability flags

#### Fact-check agent

Purpose:

* investigate extracted claims and return a confidence-weighted verdict with rationale and citations where available

Output:

* structured fact-check result

#### Personality agents

Purpose:

* produce commentary in a specific style

Output:

* either comment or abstain

#### Scheduler/ranker

Purpose:

* select whether anyone should speak and which response to surface

Output:

* zero or one selected comment in the initial version

### Implementation guidance

* Use RubyLLM for all agent interactions
* Prefer structured output schemas wherever possible
* Keep prompts and schemas versioned and inspectable
* Keep each agent mostly stateless and pass only the context needed for that step

---

## 13. Context strategy

The system should not simply feed the last 100 words to the LLM and ask for a reaction.

Instead, it should provide a layered context window such as:

* latest finalized turn
* previous few finalized turns
* rolling summary of the recent discussion
* recent comments already made by the system
* recent claims and fact-check results when relevant

This should minimize repetition and improve coherence while keeping prompt size small.

---

## 14. Testing and development strategy

This is a critical part of the product.

### Core principle

Development should be based primarily on replayable captured transcript event streams, not only on live end-to-end tests.

### Recommended fixture layers

The system should preserve at least three testable layers:

1. **Raw provider events**
   Exact transcript events as received from Deepgram, including timing and finalization data.

2. **Normalized turns**
   The resulting turns/utterances after passing through the turn builder.

3. **Agent outputs**
   Gate decisions, claims, fact-check results, and commentary outputs.

### Required development modes

#### Live capture mode

Used to capture real transcript event sessions from actual streams.

#### Replay mode

Used to replay captured sessions through the pipeline deterministically.

#### Turn-only mode

Used to iterate quickly on prompts and logic from already-normalized turns.

#### Cached-LLM mode

Used to avoid re-running identical prompts during development.

### Testing layers

#### Unit tests

For pure logic such as:

* turn building
* segmentation rules
* cooldown logic
* scheduler ranking
* replay timing behavior

#### Contract tests

To validate that raw transcript fixtures become expected normalized turns.

#### Prompt/schema tests

To validate that LLM calls return valid structured outputs and behave sensibly on known examples.

#### Regression fixtures

Known tricky examples should be preserved so changes can be checked against expected behavior.

Examples:

* speaker pauses halfway through a point and the system should wait
* speaker makes a clear factual claim and the system should fact-check
* speaker makes a weak repetitive point and the system should ignore

### Debugging requirements

The system should provide an internal interface that makes it easy to inspect a session step by step.

Useful controls may include:

* play
* pause
* speed up replay
* step to next event
* step to next finalized turn
* re-run downstream analysis for a turn
* compare cached vs live LLM outputs

---

## 15. Admin/debug UI requirements

The first version should prioritize debugging and visibility over design polish.

The internal UI should make it easy to inspect:

* session metadata
* current stream status
* latest raw transcript events
* current in-progress turn
* finalized turns in order
* decisions and outputs generated per turn
* current rolling summary
* recent comments and cooldown state
* fact-check outcomes

The operator should be able to answer questions like:

* Why did the system stay silent here?
* Why did it comment too early?
* Why did it think this was factual?
* Why did this personality win?
* What changed between the raw provider event and the final turn?

---

## 16. Prompting and output philosophy

The AI agent implementing this should follow these principles:

* prefer structured outputs over prose when the output is consumed by code
* design prompts so that agents are conservative and abstain often
* separate understanding from style
* avoid requiring long chat memory when compact state can be passed explicitly
* keep prompts versionable and easy to compare
* make every stage independently testable

---

## 17. Suggested rollout phases

### Phase 1: transcript ingestion and replay foundation

Deliver:

* Deepgram live transcription integration
* raw event persistence
* turn builder
* replay mode from captured sessions
* internal UI showing raw events and turns

Success criteria:

* a captured session can be replayed and produce the same turns consistently

### Phase 2: gatekeeper and single personality

Deliver:

* gatekeeper agent
* rolling summary
* one personality agent
* comment selection logic
* UI showing decisions and selected comment

Success criteria:

* the system can watch a replayed session and produce reasonable comment timing without obvious spam

### Phase 3: claim extraction and fact-check path

Deliver:

* claim extraction agent
* fact-check workflow
* UI for claim inspection and verdicts

Success criteria:

* the system identifies concrete factual claims and can surface useful verification output

### Phase 4: multiple personalities and ranking

Deliver:

* multiple personality agents
* scheduler/ranker improvements
* cooldown tuning
* personality controls in the UI

Success criteria:

* multiple personalities can coexist without creating noise or repetition

### Phase 5: polish and output channels

Deliver:

* improved admin UX
* overlay or external feed support
* persistence and analytics improvements
* experiment tooling for prompt/model comparison

---

## 18. Acceptance criteria for the first meaningful version

A first meaningful version should satisfy all of the following:

* It can process a live transcript session from YouTube audio via Deepgram
* It stores raw transcript events and can replay them later
* It converts transcript events into coherent finalized turns
* It runs a gatekeeper decision on completed turns
* It supports at least one commentary personality
* It can abstain and remain silent when appropriate
* It includes an internal debug UI showing why the system reacted or not
* It supports replay-based development and iteration
* It uses Rails and RubyLLM in a modular, inspectable architecture

---

## 19. Key implementation guidance for the coding agent

The coding agent should optimize for:

* clean boundaries between ingestion, transcript normalization, agent reasoning, scheduling, and UI
* service objects or equivalent modular abstractions
* job-based asynchronous processing where appropriate
* structured state and persisted auditability
* replayability and debuggability from day one

The coding agent should avoid:

* coupling personalities directly to raw transcript snippets
* sending every transcript fragment to the LLM
* hiding critical state inside opaque long-running chats
* building a flashy UI before the debugging and replay loop works well

---

## 20. Open questions and future expansion

These do not need to block the first version, but the architecture should leave room for them:

* How should speaker changes be handled if multiple hosts are present?
* Which fact-checking sources and tools should be trusted first?
* Should comments be shown immediately or only after confirmation for certain claim types?
* Should some personalities specialize in humor while others specialize in analysis?
* Should the system later score host credibility over time?
* Should transcripts and outputs later be turned into clips, summaries, or social posts?
* Should the system support multiple streams concurrently?

---

## 21. Final build instruction

Build the system as a modular, replayable real-time transcript intelligence pipeline in Rails using RubyLLM.

Prioritize:

1. transcript capture and replay
2. turn building
3. gatekeeper reasoning
4. one personality commentary path
5. internal debug visibility

Once those are solid, expand into claim extraction, fact-checking, and multiple personalities.

