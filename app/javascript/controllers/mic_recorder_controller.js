import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["micButton", "tabButton", "stopButton", "status", "idleUI", "noTabNote"]
  static values = { socketUrl: String, workletUrl: String }

  connect() {
    this.canTab = this.#detectTabAudio()
    if (!this.canTab) {
      if (this.hasTabButtonTarget) this.tabButtonTarget.hidden = true
      if (this.hasNoTabNoteTarget) this.noTabNoteTarget.hidden = false
    }
  }

  startMic() {
    this.#start("microphone", () => navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, channelCount: 1 }
    }))
  }

  startTab() {
    this.#start("tab audio", async () => {
      const stream = await navigator.mediaDevices.getDisplayMedia({
        audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false },
        video: true
      })
      stream.getVideoTracks().forEach((track) => track.stop())
      if (stream.getAudioTracks().length === 0) {
        stream.getTracks().forEach((t) => t.stop())
        throw new Error("No audio — pick a browser tab and check 'Share tab audio' in the picker.")
      }
      return stream
    })
  }

  stop() {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) this.ws.close()
    this.cleanup("Stopped.")
  }

  async #start(label, getStream) {
    if (this.active) return
    try {
      this.#setButtonsDisabled(true)
      this.#setStatus(`Requesting ${label}…`)

      this.stream = await getStream()

      this.ctx = new AudioContext({ sampleRate: 16000 })
      await this.ctx.audioWorklet.addModule(this.workletUrlValue)
      const src = this.ctx.createMediaStreamSource(this.stream)
      this.node = new AudioWorkletNode(this.ctx, "pcm-worklet")

      this.ws = new WebSocket(this.socketUrlValue)
      this.ws.binaryType = "arraybuffer"
      await new Promise((resolve, reject) => {
        this.ws.addEventListener("open", resolve, { once: true })
        this.ws.addEventListener("error", reject, { once: true })
      })
      this.ws.addEventListener("close", () => this.cleanup("Recording ended."))

      this.node.port.onmessage = (event) => {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) this.ws.send(event.data)
      }
      src.connect(this.node)

      this.stream.getAudioTracks().forEach((track) => {
        track.addEventListener("ended", () => this.stop(), { once: true })
      })

      this.active = true
      this.#showActive(label)
    } catch (err) {
      this.#showIdle(`Error: ${err.message}`)
      this.cleanup()
    }
  }

  cleanup(msg) {
    this.active = false
    if (this.node) this.node.disconnect()
    if (this.stream) this.stream.getTracks().forEach((t) => t.stop())
    if (this.ctx && this.ctx.state !== "closed") this.ctx.close()
    this.node = this.stream = this.ctx = null
    this.#showIdle(msg)
  }

  #showActive(label) {
    if (this.hasIdleUITarget) this.idleUITarget.hidden = true
    if (this.hasStopButtonTarget) this.stopButtonTarget.hidden = false
    this.#setStatus(`Recording from ${label}…`)
    this.#setButtonsDisabled(false)
  }

  #showIdle(msg) {
    if (this.hasIdleUITarget) this.idleUITarget.hidden = false
    if (this.hasStopButtonTarget) this.stopButtonTarget.hidden = true
    if (this.hasTabButtonTarget) this.tabButtonTarget.hidden = !this.canTab
    if (this.hasMicButtonTarget) this.micButtonTarget.hidden = false
    if (msg) this.#setStatus(msg); else this.#hideStatus()
    this.#setButtonsDisabled(false)
  }

  #setStatus(text) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.hidden = false
  }

  #hideStatus() {
    if (this.hasStatusTarget) this.statusTarget.hidden = true
  }

  #setButtonsDisabled(disabled) {
    for (const target of [this.micButtonTarget, this.tabButtonTarget, this.stopButtonTarget]) {
      if (target) target.disabled = disabled
    }
  }

  #detectTabAudio() {
    const ua = navigator.userAgent
    // Only Chromium-based browsers honor audio in getDisplayMedia. Safari and
    // Firefox expose the API but silently drop the audio track.
    const isChromium = /\b(Chrome|Chromium|Edg|OPR|Brave)\//.test(ua) &&
                       !/\b(FxiOS|CriOS)\//.test(ua)
    return isChromium && !!navigator.mediaDevices?.getDisplayMedia
  }

  disconnect() { this.cleanup() }
}
