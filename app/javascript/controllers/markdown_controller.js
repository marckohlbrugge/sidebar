import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

// Renders the comment body as markdown, extracting every link (explicit or
// autolink) into a numbered sources list below the text. Body stays readable;
// citations appear as "[N]" markers inline.
export default class extends Controller {
  static targets = ["body", "sources"]
  static values = { text: String }

  connect() {
    const raw = this.textValue || (this.hasBodyTarget ? this.bodyTarget.textContent : "")
    const { html, sources } = this.#format(raw)
    if (this.hasBodyTarget) this.bodyTarget.innerHTML = html
    this.#renderSources(sources)
  }

  #format(text) {
    const sources = []
    const wrapper = document.createElement("div")
    wrapper.innerHTML = marked.parseInline(text)

    for (const a of wrapper.querySelectorAll("a[href]")) {
      const url = a.getAttribute("href")
      let idx = sources.findIndex((s) => s.url === url)
      if (idx === -1) { sources.push({ url, label: a.textContent }); idx = sources.length - 1 }
      a.replaceWith(document.createTextNode(`[${idx + 1}]`))
    }

    return { html: wrapper.innerHTML, sources }
  }

  #renderSources(sources) {
    if (!this.hasSourcesTarget) return
    if (sources.length === 0) {
      this.sourcesTarget.innerHTML = ""
      this.sourcesTarget.hidden = true
      return
    }
    this.sourcesTarget.hidden = false
    this.sourcesTarget.replaceChildren(
      ...sources.map((s, i) => {
        const li = document.createElement("li")
        li.className = "flex gap-2"
        const marker = document.createElement("span")
        marker.className = "opacity-60 shrink-0"
        marker.textContent = `[${i + 1}]`
        const link = document.createElement("a")
        link.href = s.url
        link.target = "_blank"
        link.rel = "noopener noreferrer"
        link.className = "underline break-all opacity-80 hover:opacity-100"
        link.textContent = this.#displayUrl(s.url)
        li.append(marker, link)
        return li
      })
    )
  }

  #displayUrl(u) {
    try {
      const p = new URL(u)
      return (p.hostname.replace(/^www\./, "") + p.pathname).replace(/\/$/, "")
    } catch {
      return u
    }
  }
}
