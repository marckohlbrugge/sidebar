import { Controller } from "@hotwired/stimulus"

// Replay a finished session in the browser.
//
// Two modes:
//
//   Video-driven (when a YouTube player target is present):
//   - The video's currentTime drives reveal. Items with
//     data-show-at-ms ≤ currentTime*1000 are visible, others hidden.
//   - Seek handling comes for free: whatever the user scrubs to,
//     we recompute visibility on the next poll tick.
//
//   Timer-driven (no video):
//   - Walk through items on setTimeout, clamped gaps so dead air
//     doesn't drag.
//
// Turn highlights are reapplied from the comment's
// data-highlight-classes whenever a comment is visible.

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
    this.boundYtReady = this.#onYtReady
    window.addEventListener("youtube:ready", this.boundYtReady)
    if (this.hasVideoTarget && this.videoIdValue) {
      this.#initPlayer()
    }
    if (this.autoplayValue) this.start()
  }

  disconnect() {
    this.#clear()
    window.removeEventListener("youtube:ready", this.boundYtReady)
    if (this.pollId) cancelAnimationFrame(this.pollId)
  }

  start() {
    this.#clear()
    this.#hideAll()
    this.#clearAllHighlights()
    document.getElementById("timeline")?.classList.remove("replay-pending")
    window.scrollTo({ top: 0, behavior: "smooth" })

    if (this.player && typeof this.player.playVideo === "function") {
      this.player.seekTo(0, true)
      this.player.playVideo()
      this.#startPolling()
    } else {
      this.#startTimerReveal()
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
    if (window.YT && window.YT.Player) {
      this.#createPlayer()
    }
    // else wait for youtube:ready event; handler runs #createPlayer.
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
        origin: window.location.origin
      },
      events: {
        onReady: () => { /* ready, awaiting start */ },
        onStateChange: (event) => {
          if (event.data === YT.PlayerState.PLAYING) this.#startPolling()
          if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) this.#stopPolling()
        }
      }
    })
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

  #startTimerReveal() {
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
