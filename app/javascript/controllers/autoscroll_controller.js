import { Controller } from "@hotwired/stimulus"

// Smart autoscroll:
// - If user is near the bottom, pin to bottom as new content arrives
// - If user has scrolled up, don't interrupt — show a "jump to latest" button instead
// Scrolls the window, since the page uses normal body scroll.

const NEAR_BOTTOM_PX = 240

export default class extends Controller {
  static targets = ["latest"]

  #wasNearBottom = true

  connect() {
    this.#scrollToBottom(false)
    this.#boundBefore = this.#rememberPosition.bind(this)
    this.#boundAfter = this.#respond.bind(this)
    this.#boundScroll = this.#onScroll.bind(this)
    document.addEventListener("turbo:before-stream-render", this.#boundBefore)
    document.addEventListener("turbo:after-stream-render", this.#boundAfter)
    window.addEventListener("scroll", this.#boundScroll, { passive: true })
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.#boundBefore)
    document.removeEventListener("turbo:after-stream-render", this.#boundAfter)
    window.removeEventListener("scroll", this.#boundScroll)
  }

  jumpToLatest() {
    this.#scrollToBottom(true)
    this.#hideBadge()
  }

  #rememberPosition() {
    this.#wasNearBottom = this.#isNearBottom()
  }

  #respond() {
    if (this.#wasNearBottom) {
      this.#scrollToBottom(true)
    } else {
      this.#showBadge()
    }
  }

  #onScroll() {
    if (this.#isNearBottom()) this.#hideBadge()
  }

  #isNearBottom() {
    const scrolled = window.innerHeight + window.scrollY
    return scrolled >= document.documentElement.scrollHeight - NEAR_BOTTOM_PX
  }

  #scrollToBottom(smooth) {
    window.scrollTo({
      top: document.documentElement.scrollHeight,
      behavior: smooth ? "smooth" : "auto"
    })
  }

  #showBadge() {
    if (this.hasLatestTarget) this.latestTarget.hidden = false
  }

  #hideBadge() {
    if (this.hasLatestTarget) this.latestTarget.hidden = true
  }
}
