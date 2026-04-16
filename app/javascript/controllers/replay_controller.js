import { Controller } from "@hotwired/stimulus"

// Replay a finished session in the browser. Every turn and comment
// is already rendered with `data-show-at-ms`. We hide them, then
// reveal each at its original offset, clamped so dead air doesn't
// drag. Turn highlights are stripped on start and re-applied when
// their comment appears, so the highlight arrives with the comment
// (matching live-mode feel).

const MIN_GAP_MS = 300
const MAX_GAP_MS = 4000

export default class extends Controller {
  static targets = ["item"]
  static values = { autoplay: Boolean }

  connect() {
    this.timeouts = []
    if (this.autoplayValue) this.start()
  }

  disconnect() {
    this.#clear()
  }

  start() {
    this.#clear()

    const items = [...this.itemTargets].sort((a, b) =>
      Number(a.dataset.showAtMs) - Number(b.dataset.showAtMs)
    )
    items.forEach((el) => el.classList.add("hidden"))
    document.getElementById("timeline")?.classList.remove("replay-pending")
    this.#stripAllHighlights()
    window.scrollTo({ top: 0, behavior: "smooth" })

    let elapsed = 0
    let previous = 0

    items.forEach((el) => {
      const at = Number(el.dataset.showAtMs)
      const gap = Math.max(MIN_GAP_MS, Math.min(MAX_GAP_MS, at - previous))
      elapsed += gap
      previous = at

      const id = setTimeout(() => this.#reveal(el), elapsed)
      this.timeouts.push(id)
    })
  }

  stop() {
    this.#clear()
    this.itemTargets.forEach((el) => el.classList.remove("hidden"))
    this.#restoreAllHighlights()
  }

  #reveal(el) {
    el.classList.remove("hidden")
    if (el.classList.contains("comment-row")) {
      this.#applyHighlight(el)
    }
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

  #stripAllHighlights() {
    this.itemTargets
      .filter((el) => el.classList.contains("turn-row"))
      .forEach((turn) => {
        const bgClasses = [...turn.classList].filter((c) => c.match(/^(bg|dark:bg)-/))
        if (bgClasses.length) {
          turn.dataset.originalBg = bgClasses.join(" ")
          turn.classList.remove(...bgClasses)
        }
      })
  }

  #restoreAllHighlights() {
    this.itemTargets
      .filter((el) => el.classList.contains("turn-row") && el.dataset.originalBg)
      .forEach((turn) => {
        turn.classList.add(...turn.dataset.originalBg.split(/\s+/))
      })
  }

  #applyHighlight(commentEl) {
    const turnId = commentEl.dataset.turnDomId
    const classes = commentEl.dataset.highlightClasses
    if (!turnId || !classes) return
    const turn = document.getElementById(turnId)
    if (turn) turn.classList.add(...classes.split(/\s+/))
  }

  #clear() {
    this.timeouts.forEach(clearTimeout)
    this.timeouts = []
  }
}
