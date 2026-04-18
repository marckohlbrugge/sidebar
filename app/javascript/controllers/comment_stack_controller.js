import { Controller } from "@hotwired/stimulus"

// Pushes comments down the right column so they never overlap a comment
// above them. Each comment sits at max(its-own-grid-row top, previous
// comment bottom + gap). Grid structure is untouched — only transform is
// applied — so the transcript column never reflows when a comment arrives.
export default class extends Controller {
  static values = { gap: { type: Number, default: 12 } }

  connect() {
    this.schedule = this.schedule.bind(this)
    this.pending = false

    this.mo = new MutationObserver(() => this.schedule())
    this.mo.observe(this.element, { childList: true, subtree: true })

    if ("ResizeObserver" in window) {
      this.ro = new ResizeObserver(() => this.schedule())
      this.ro.observe(this.element)
    }

    window.addEventListener("resize", this.schedule)
    document.addEventListener("turbo:stream-render", this.schedule)

    this.schedule()
  }

  disconnect() {
    this.mo?.disconnect()
    this.ro?.disconnect()
    window.removeEventListener("resize", this.schedule)
    document.removeEventListener("turbo:stream-render", this.schedule)
  }

  schedule() {
    if (this.pending) return
    this.pending = true
    requestAnimationFrame(() => {
      this.pending = false
      this.restack()
    })
  }

  restack() {
    const cards = Array.from(this.element.querySelectorAll(".comment-row > div"))
    if (cards.length === 0) return

    // Reset so we measure each card's natural grid-row position.
    for (const el of cards) el.style.transform = ""

    let floor = -Infinity
    for (const el of cards) {
      // Skip comments that replay has hidden — they'll be restacked when
      // revealed via the turbo:stream-render / mutation paths.
      if (el.closest(".comment-row.hidden")) continue

      const rect = el.getBoundingClientRect()
      const naturalTop = rect.top + window.scrollY
      const delta = Math.max(0, floor - naturalTop)
      if (delta > 0) el.style.transform = `translateY(${delta}px)`
      floor = naturalTop + delta + rect.height + this.gapValue
    }
  }
}
