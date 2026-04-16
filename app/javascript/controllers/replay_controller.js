import { Controller } from "@hotwired/stimulus"

// Replay a finished session in the browser.
//
// Video-driven (when a YouTube player target is present):
// - Transcript stays hidden until the video starts playing.
// - Video's currentTime drives reveals; scrubbing updates visibility
//   on the next poll tick.
//
// Timer-driven (no video): walk items on setTimeout.
//
// Turn highlights are applied from the comment's
// data-highlight-classes whenever a comment becomes visible.

const MIN_GAP_MS = 300
const MAX_GAP_MS = 4000
const POLL_MS = 200

export default class extends Controller {
  static targets = ["item", "video"]
  static values = {
    autoplay: Boolean,
    videoId: String
  }

  connect() {
    this.timeouts = []
    window.addEventListener("youtube:ready", this.#onYtReady)

    if (this.hasVideoTarget && this.videoIdValue) {
      this.#initPlayer()
      // Items stay hidden via the server-rendered `replay-pending`
      // class until the video actually starts playing.
    } else if (this.autoplayValue) {
      this.#beginTimerReveal()
    }
  }

  disconnect() {
    window.removeEventListener("youtube:ready", this.#onYtReady)
    this.#stopPolling()
    this.#clear()
  }

  // REPLAY button: (re)start playback from the beginning.
  start() {
    this.#clear()
    if (this.player?.playVideo) {
      this.player.seekTo(0, true)
      this.player.playVideo()
      // onStateChange -> PLAYING will drive the rest.
    } else {
      this.#beginTimerReveal()
    }
  }

  stop() {
    this.#clear()
    this.#stopPolling()
    this.player?.pauseVideo?.()
    this.itemTargets.forEach((el) => el.classList.remove("hidden"))
  }

  // ───── video-driven reveal ────────────────────────────────

  #initPlayer = () => {
    if (window.YT && window.YT.Player) this.#createPlayer()
    // else wait for youtube:ready event.
  }

  #onYtReady = () => {
    if (this.hasVideoTarget && !this.player) this.#createPlayer()
  }

  #createPlayer = () => {
    this.player = new YT.Player(this.videoTarget, {
      videoId: this.videoIdValue,
      host: "https://www.youtube-nocookie.com",
      playerVars: {
        playsinline: 1,
        rel: 0,
        modestbranding: 1,
        origin: window.location.origin,
        autoplay: this.autoplayValue ? 1 : 0,
        mute: this.autoplayValue ? 1 : 0
      },
      events: {
        onReady: () => { /* ready, awaiting play */ },
        onStateChange: this.#onPlayerStateChange
      }
    })
  }

  #onPlayerStateChange = (event) => {
    if (event.data === YT.PlayerState.PLAYING) this.#beginVideoReveal()
    if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
      this.#stopPolling()
    }
  }

  #beginVideoReveal() {
    if (this.videoRevealActive) {
      this.#startPolling()
      return
    }
    this.videoRevealActive = true
    this.#hideAll()
    this.#clearAllHighlights()
    document.getElementById("timeline")?.classList.remove("replay-pending")
    this.#startPolling()
  }

  #startPolling() {
    this.#stopPolling()
    const tick = () => {
      if (!this.player) return
      const ms = Math.floor((this.player.getCurrentTime?.() ?? 0) * 1000)
      this.#advanceTo(ms)
      this.pollId = window.setTimeout(tick, POLL_MS)
    }
    tick()
  }

  #stopPolling() {
    if (this.pollId) window.clearTimeout(this.pollId)
    this.pollId = null
  }

  #advanceTo(ms) {
    this.itemTargets.forEach((el) => {
      const at = Number(el.dataset.showAtMs)
      const shouldShow = at <= ms
      const isHidden = el.classList.contains("hidden")
      if (shouldShow && isHidden) {
        el.classList.remove("hidden")
        if (el.classList.contains("comment-row")) this.#applyHighlight(el)
      } else if (!shouldShow && !isHidden) {
        el.classList.add("hidden")
        if (el.classList.contains("comment-row")) this.#removeHighlight(el)
      }
    })
  }

  // ───── timer-driven reveal (no video) ─────────────────────

  #beginTimerReveal() {
    this.#hideAll()
    this.#clearAllHighlights()
    document.getElementById("timeline")?.classList.remove("replay-pending")

    const items = [...this.itemTargets].sort((a, b) =>
      Number(a.dataset.showAtMs) - Number(b.dataset.showAtMs)
    )

    let elapsed = 0
    let previous = 0

    items.forEach((el) => {
      const at = Number(el.dataset.showAtMs)
      const gap = Math.max(MIN_GAP_MS, Math.min(MAX_GAP_MS, at - previous))
      elapsed += gap
      previous = at

      const id = setTimeout(() => this.#revealOne(el), elapsed)
      this.timeouts.push(id)
    })
  }

  #revealOne(el) {
    el.classList.remove("hidden")
    if (el.classList.contains("comment-row")) this.#applyHighlight(el)

    const nearBottom = window.innerHeight + window.scrollY >=
      document.documentElement.scrollHeight - 240
    if (nearBottom) this.#tail()
  }

  #tail() {
    if (this.tailScheduled) return
    this.tailScheduled = true
    setTimeout(() => {
      window.scrollTo({ top: document.documentElement.scrollHeight, behavior: "smooth" })
      this.tailScheduled = false
    }, 120)
  }

  // ───── highlight + utility helpers ────────────────────────

  #hideAll() {
    this.itemTargets.forEach((el) => el.classList.add("hidden"))
  }

  #applyHighlight(comment) {
    const turn = document.getElementById(comment.dataset.turnDomId)
    const classes = comment.dataset.highlightClasses
    if (!turn || !classes) return
    turn.classList.add(...classes.split(/\s+/))
    turn.dataset.appliedHighlight = classes
  }

  #removeHighlight(comment) {
    const turn = document.getElementById(comment.dataset.turnDomId)
    if (!turn?.dataset.appliedHighlight) return
    turn.classList.remove(...turn.dataset.appliedHighlight.split(/\s+/))
    delete turn.dataset.appliedHighlight
  }

  #clearAllHighlights() {
    document.querySelectorAll(".turn-row[data-applied-highlight]").forEach((turn) => {
      turn.classList.remove(...turn.dataset.appliedHighlight.split(/\s+/))
      delete turn.dataset.appliedHighlight
    })
  }

  #clear() {
    this.timeouts.forEach(clearTimeout)
    this.timeouts = []
  }
}
