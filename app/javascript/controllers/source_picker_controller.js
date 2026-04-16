import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlField", "urlInput"]

  switch(event) {
    const isUrl = event.currentTarget.value === "url"
    this.urlFieldTarget.classList.toggle("hidden", !isUrl)
    this.urlInputTarget.disabled = !isUrl
  }
}
