import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "researchBtn", "brief", "briefContent", "useBtn", "status" ]
  static values  = { url: String }

  connect() {
    this._brief      = ""
    this._abortCtrl  = null
  }

  research() {
    const prompt = this._promptEl()?.value.trim()
    if (!prompt) { this._setStatus("Enter a topic first", true); return }

    this._brief = ""
    this.briefContentTarget.textContent = ""
    this.briefTarget.classList.remove("hidden")
    this.useBtnTarget.classList.add("hidden")
    this.researchBtnTarget.disabled = true
    this._setStatus("Researching…")

    if (this._abortCtrl) this._abortCtrl.abort()
    const ctrl = new AbortController()
    this._abortCtrl = ctrl

    const enriched = `Research this topic thoroughly for a magazine article. Provide key facts, historical context, interesting angles, and cite your sources:\n\n${prompt}`

    fetch(this.urlValue, {
      method:  "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body:   `prompt=${encodeURIComponent(enriched)}`,
      signal: ctrl.signal
    }).then(res => {
      if (!res.ok) return res.text().then(t => { throw new Error(`HTTP ${res.status}: ${t.slice(0, 200)}`) })

      const reader  = res.body.getReader()
      const decoder = new TextDecoder()
      let buffer    = ""
      let eventType = "data"

      const pump = () => reader.read().then(({ done, value }) => {
        if (done) { this._onDone(); return }
        buffer += decoder.decode(value, { stream: true })

        const lines = buffer.split("\n")
        buffer = lines.pop()

        for (const line of lines) {
          if (line.startsWith("event: ")) { eventType = line.slice(7).trim(); continue }
          if (!line.startsWith("data: ")) { eventType = "data"; continue }

          const payload = line.slice(6)

          if (eventType === "done") { this._onDone(); return }
          if (eventType === "error") { this._setStatus(`Error: ${payload}`, true); this.researchBtnTarget.disabled = false; return }

          // Server sends JSON-encoded strings: "text chunk"
          let text = payload
          try { text = JSON.parse(payload) } catch (e) {}

          this._brief += text
          this.briefContentTarget.textContent = this._brief
          this.briefContentTarget.scrollTop   = this.briefContentTarget.scrollHeight
          eventType = "data"
        }
        pump()
      })
      pump()
    }).catch(err => {
      if (err.name !== "AbortError") {
        this._setStatus(`Error: ${err.message}`, true)
        this.researchBtnTarget.disabled = false
      }
    })
  }

  useBrief() {
    const el = this._promptEl()
    if (!el || !this._brief) return
    const existing = el.value.trim()
    el.value = existing
      ? `${existing}\n\n---\nResearch context:\n\n${this._brief}`
      : this._brief
    this._setStatus("Research added to prompt ↑")
    el.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  _onDone() {
    this.researchBtnTarget.disabled = false
    this._setStatus("Done")
    if (this._brief) this.useBtnTarget.classList.remove("hidden")
  }

  _promptEl() {
    return this.element.querySelector('[data-lexxy-assistant-target="prompt"]')
  }

  _setStatus(msg, isError = false) {
    this.statusTarget.textContent = msg
    this.statusTarget.classList.toggle("text-red-500",  isError)
    this.statusTarget.classList.toggle("text-gray-500", !isError)
  }
}
