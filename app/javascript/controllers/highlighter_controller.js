import { Controller } from "@hotwired/stimulus"

// Applies the persona bg classes of every visible comment to its
// paired turn. Re-runs on DOM changes (Turbo appends) and class
// changes (replay showing/hiding items) so both live and replay
// modes light up the turn in sync with its comment.

export default class extends Controller {
  connect() {
    this.#apply()
    this.observer = new MutationObserver(() => this.#apply())
    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
      attributeFilter: ["class"]
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #apply = () => {
    this.#clearAppliedHighlights()
    this.element.querySelectorAll(".comment-row:not(.hidden)").forEach((comment) => {
      const turn = document.getElementById(comment.dataset.turnDomId)
      const classes = comment.dataset.highlightClasses
      if (!turn || !classes) return
      turn.classList.add(...classes.split(/\s+/))
      turn.dataset.appliedHighlight = classes
    })
  }

  #clearAppliedHighlights() {
    this.element.querySelectorAll(".turn-row[data-applied-highlight]").forEach((turn) => {
      turn.classList.remove(...turn.dataset.appliedHighlight.split(/\s+/))
      delete turn.dataset.appliedHighlight
    })
  }
}
