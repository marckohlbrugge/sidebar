import { Controller } from "@hotwired/stimulus"

// Paints each visible comment's persona background onto its paired
// turn. On page load it highlights everything visible; after that it
// only reacts to new comments appended by Turbo. Replay toggles
// `.hidden` itself and manages highlights directly — no attribute
// watching here (that caused a feedback loop).

export default class extends Controller {
  connect() {
    this.#applyAll()
    this.observer = new MutationObserver(this.#handleAdditions)
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #handleAdditions = (mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType !== 1) continue
        if (node.classList.contains("comment-row")) {
          this.#applyOne(node)
        } else {
          node.querySelectorAll?.(".comment-row").forEach((el) => this.#applyOne(el))
        }
      }
    }
  }

  #applyAll = () => {
    this.element.querySelectorAll(".comment-row:not(.hidden)").forEach(this.#applyOne)
  }

  #applyOne = (comment) => {
    if (comment.classList.contains("hidden")) return
    const turn = document.getElementById(comment.dataset.turnDomId)
    const classes = comment.dataset.highlightClasses
    if (!turn || !classes) return
    turn.classList.add(...classes.split(/\s+/))
    turn.dataset.appliedHighlight = classes
  }
}
