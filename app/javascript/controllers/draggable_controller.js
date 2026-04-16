import { Controller } from "@hotwired/stimulus"

// Draggable + snap-to-corner. Remembers which corner across reloads.
//
// Drags start on pointerdown anywhere in the element (except children
// tagged with `data-draggable-no-drag`). A click that stays within
// DRAG_THRESHOLD pixels is treated as a normal click so <summary>
// still toggles. On release, animates to the nearest viewport corner.

const DRAG_THRESHOLD = 5
const MARGIN = 24
const HEADER_OFFSET = 72  // room below the sticky app header

export default class extends Controller {
  static values = { storageKey: { type: String, default: "armchair:pip" } }

  connect() {
    this.#restore()
    this.element.addEventListener("pointerdown", this.#onDown)
    window.addEventListener("resize", this.#onResize)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.#onDown)
    window.removeEventListener("resize", this.#onResize)
    window.removeEventListener("pointermove", this.#onMove)
  }

  #onDown = (event) => {
    if (event.target.closest("[data-draggable-no-drag]")) return
    if (event.button !== 0 && event.pointerType === "mouse") return

    this.start = { x: event.clientX, y: event.clientY }
    this.dragged = false
    const rect = this.element.getBoundingClientRect()
    this.initial = { left: rect.left, top: rect.top }
    window.addEventListener("pointermove", this.#onMove)
    window.addEventListener("pointerup", this.#onUp, { once: true })
  }

  #onMove = (event) => {
    const dx = event.clientX - this.start.x
    const dy = event.clientY - this.start.y

    if (!this.dragged && Math.hypot(dx, dy) < DRAG_THRESHOLD) return
    if (!this.dragged) {
      this.dragged = true
      this.element.style.transition = "none"
      this.element.style.right = "auto"
      this.element.style.bottom = "auto"
      this.element.classList.add("select-none", "cursor-grabbing")
      // Block the click that follows pointerup from toggling <details>.
      this.element.addEventListener("click", this.#absorbClick, { once: true, capture: true })
    }

    event.preventDefault()
    this.element.style.left = `${this.initial.left + dx}px`
    this.element.style.top = `${this.initial.top + dy}px`
  }

  #onUp = () => {
    window.removeEventListener("pointermove", this.#onMove)
    this.element.classList.remove("select-none", "cursor-grabbing")
    if (!this.dragged) return
    this.#snap()
  }

  #absorbClick = (event) => {
    event.stopPropagation()
    event.preventDefault()
  }

  #snap() {
    const rect = this.element.getBoundingClientRect()
    const cx = rect.left + rect.width / 2
    const cy = rect.top + rect.height / 2
    const corner = {
      left: cx < window.innerWidth / 2,
      top: cy < window.innerHeight / 2
    }
    this.element.style.transition = "left 200ms ease, top 200ms ease"
    this.#placeAt(corner, rect)
    this.#save(corner)
  }

  #placeAt(corner, rect) {
    const x = corner.left ? MARGIN : window.innerWidth - rect.width - MARGIN
    const y = corner.top ? HEADER_OFFSET : window.innerHeight - rect.height - MARGIN
    this.element.style.left = `${x}px`
    this.element.style.top = `${y}px`
  }

  #restore() {
    const corner = this.#load()
    if (!corner) return
    requestAnimationFrame(() => {
      const rect = this.element.getBoundingClientRect()
      this.element.style.transition = "none"
      this.element.style.right = "auto"
      this.element.style.bottom = "auto"
      this.#placeAt(corner, rect)
    })
  }

  #onResize = () => {
    const corner = this.#load()
    if (!corner) return
    const rect = this.element.getBoundingClientRect()
    this.#placeAt(corner, rect)
  }

  #save(corner) {
    try { localStorage.setItem(this.storageKeyValue, JSON.stringify(corner)) } catch (_) {}
  }

  #load() {
    try { return JSON.parse(localStorage.getItem(this.storageKeyValue) || "null") }
    catch (_) { return null }
  }
}
