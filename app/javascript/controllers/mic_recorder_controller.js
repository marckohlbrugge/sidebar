import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status"]
  static values = { socketUrl: String, workletUrl: String }

  async toggle() {
    if (this.active) return this.stop()
    await this.start()
  }

  async start() {
    try {
      this.buttonTarget.disabled = true
      this.setStatus("Requesting microphone…")

      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, channelCount: 1 }
      })

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

      this.active = true
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "■ STOP"
      this.setStatus("Recording…")
    } catch (err) {
      this.setStatus(`Error: ${err.message}`)
      this.buttonTarget.disabled = false
      this.cleanup()
    }
  }

  stop() {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) this.ws.close()
    this.cleanup("Stopped.")
  }

  cleanup(msg) {
    this.active = false
    if (this.node) this.node.disconnect()
    if (this.stream) this.stream.getTracks().forEach((t) => t.stop())
    if (this.ctx && this.ctx.state !== "closed") this.ctx.close()
    this.node = this.stream = this.ctx = null
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "● START RECORDING"
    }
    if (msg) this.setStatus(msg)
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  disconnect() { this.cleanup() }
}
