// Runs in AudioWorkletGlobalScope. Consumes the browser's native-rate mono
// audio, linearly resamples to 16 kHz, converts to Int16, and emits ~100 ms
// Int16 chunks (1600 samples) back to the main thread for WebSocket shipping.
class PcmWorklet extends AudioWorkletProcessor {
  constructor() {
    super()
    this.targetRate = 16000
    this.ratio = sampleRate / this.targetRate
    this.srcPos = 0
    this.pending = []
    this.chunkSize = 1600
  }

  process(inputs) {
    const channel = inputs[0] && inputs[0][0]
    if (!channel) return true

    while (this.srcPos < channel.length) {
      const i = Math.floor(this.srcPos)
      const t = this.srcPos - i
      const s0 = channel[i] ?? 0
      const s1 = channel[i + 1] ?? s0
      const sample = s0 + (s1 - s0) * t
      const clamped = Math.max(-1, Math.min(1, sample))
      this.pending.push(clamped < 0 ? clamped * 0x8000 : clamped * 0x7fff)
      this.srcPos += this.ratio
    }
    this.srcPos -= channel.length

    if (this.pending.length >= this.chunkSize) {
      const out = new Int16Array(this.pending)
      this.pending = []
      this.port.postMessage(out.buffer, [out.buffer])
    }
    return true
  }
}

registerProcessor("pcm-worklet", PcmWorklet)
