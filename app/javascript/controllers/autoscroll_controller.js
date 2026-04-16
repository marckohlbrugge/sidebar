import { Controller } from "@hotwired/stimulus"

// Smart autoscroll:
// - If user is near the bottom, pin to bottom as new content arrives
// - If user has scrolled up, don't interrupt — show a "jump to latest" button instead
// Scrolls the window, since the page uses normal body scroll.

const NEAR_BOTTOM_PX = 240

export default class extends Controller {
  static targets = ["latest"]

  #wasNearBottom = true
  #tailScheduled = false

  connect() {
    this.#scrollToBottom(false)
    document.addEventListener("turbo:before-stream-render", this.#rememberPosition)
    document.addEventListener("turbo:after-stream-render", this.#respond)
    window.addEventListener("scroll", this.#onScroll, { passive: true })
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.#rememberPosition)
    document.removeEventListener("turbo:after-stream-render", this.#respond)
    window.removeEventListener("scroll", this.#onScroll)
  }

  jumpToLatest() {
    this.#scrollToBottom(true)
    this.#hideBadge()
  }

  #rememberPosition = () => {
    this.#wasNearBottom = this.#isNearBottom()
  }

  #respond = () => {
    if (this.#wasNearBottom) {
      this.#tail()
    } else {
      this.#showBadge()
    }
  }

  #onScroll = () => {
    if (this.#isNearBottom()) this.#hideBadge()
  }

  #tail() {
    if (this.#tailScheduled) return
    this.#tailScheduled = true
    setTimeout(() => {
      this.#scrollToBottom(true)
      this.#tailScheduled = false
    }, 120)
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
