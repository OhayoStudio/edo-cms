import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "chevron", "prompt", "generateBtn", "applyBtn", "insertBtn", "status", "output", "usage" ]
  static values  = { draftUrl: String, patchUrl: String }

  connect() {
    this._accumulated = ""
    this._parsed      = null
    this._source      = null
    this._bodyInserted = false

    // Safety net: re-apply body just before Turbo serialises the form
    this._submitHandler = () => {
      if (!this._bodyInserted || !this._parsed?._body) return
      const lexxy = document.querySelector("lexxy-editor")
      if (lexxy?.editor) {
        lexxy.editor.update(() => {}, { skipTransforms: true, discrete: true })
      }
    }
    this.element.closest("form")?.addEventListener("submit", this._submitHandler)
  }

  disconnect() {
    this.element.closest("form")?.removeEventListener("submit", this._submitHandler)
  }

  _setStatus(msg, isError = false) {
    this.statusTarget.textContent = msg
    this.statusTarget.classList.toggle("text-red-500",       isError)
    this.statusTarget.classList.toggle("dark:text-red-400",  isError)
    this.statusTarget.classList.toggle("text-gray-500",      !isError)
    this.statusTarget.classList.toggle("dark:text-gray-400", !isError)
  }

  toggle() {
    const hidden = this.panelTarget.classList.toggle("hidden")
    this.chevronTarget.textContent = hidden ? "▸" : "▾"
  }

  generate() {
    const prompt = this.promptTarget.value.trim()
    if (!prompt) return

    this._accumulated = ""
    this._parsed      = null
    this.outputTarget.textContent = ""
    this.outputTarget.classList.remove("hidden")
    this.usageTarget.classList.add("hidden")
    this.usageTarget.textContent = ""
    this.applyBtnTarget.classList.add("hidden")
    this.insertBtnTarget.classList.add("hidden")
    this.generateBtnTarget.disabled = true
    this._setStatus("Thinking…")

    // Persist the prompt immediately so it's saved even if the article form isn't submitted
    if (this.patchUrlValue) {
      fetch(this.patchUrlValue, {
        method:  "PATCH",
        headers: {
          "Content-Type":  "application/x-www-form-urlencoded",
          "X-CSRF-Token":  document.querySelector('meta[name="csrf-token"]').content
        },
        body: `field=claude_prompt&value=${encodeURIComponent(prompt)}`
      })
    }

    // Close any existing stream
    if (this._source) { this._source.close() }

    // SSE via POST — use fetch + ReadableStream since EventSource only supports GET
    const ctrl = new AbortController()
    this._abortCtrl = ctrl

    fetch(this.draftUrlValue, {
      method:  "POST",
      headers: {
        "Content-Type":  "application/x-www-form-urlencoded",
        "X-CSRF-Token":  document.querySelector('meta[name="csrf-token"]').content
      },
      body:   `prompt=${encodeURIComponent(prompt)}`,
      signal: ctrl.signal
    }).then(res => {
      if (!res.ok) {
        return res.text().then(t => { throw new Error(`HTTP ${res.status}: ${t.slice(0, 200)}`) })
      }

      const reader = res.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ""
      let eventType = "data"

      const processBuffer = () => {
        const lines = buffer.split("\n")
        buffer = lines.pop()           // keep incomplete line

        for (const line of lines) {
          if (line.startsWith("event: ")) {
            eventType = line.slice(7).trim()
            continue
          }
          if (!line.startsWith("data: ")) { eventType = "data"; continue }

          const payload = line.slice(6).replace(/\\n/g, "\n")

          if (eventType === "done") {
            try { this._showUsage(JSON.parse(payload)) } catch (e) { console.warn("[claude] usage parse failed:", e, payload) }
            this._onStreamEnd()
            return
          }
          if (eventType === "error") {
            this._setStatus(`Error: ${payload}`, true)
            this.generateBtnTarget.disabled = false
            return
          }

          this._accumulated += payload
          this.outputTarget.textContent = this._accumulated
          this.outputTarget.scrollTop = this.outputTarget.scrollHeight
          this._setStatus("Writing…")
          eventType = "data"
        }
      }

      const pump = () => reader.read().then(({ done, value }) => {
        if (done) {
          // Flush whatever remains in the buffer (e.g. the "done" event with usage JSON)
          if (buffer.trim()) processBuffer()
          this._onStreamEnd()
          return
        }
        buffer += decoder.decode(value, { stream: true })
        processBuffer()
        pump()
      })
      pump()
    }).catch(err => {
      if (err.name !== "AbortError") {
        this._setStatus(`Error: ${err.message}`, true)
        this.generateBtnTarget.disabled = false
        console.error(err)
      }
    })
  }

  _onStreamEnd() {
    this.generateBtnTarget.disabled = false
    this._setStatus("Done")
    this._parsed = this._parse(this._accumulated)
    this.applyBtnTarget.classList.remove("hidden")
    this.insertBtnTarget.classList.remove("hidden")
  }

  // ── Usage ──────────────────────────────────────────────────────────────────

  _showUsage(u) {
    // Opus 4.6 pricing per 1M tokens (as of 2026)
    const PRICE = { input: 5.00, output: 25.00, cache_write: 3.75, cache_read: 0.30 }
    const cost =
      (u.input_tokens                * PRICE.input        / 1_000_000) +
      (u.output_tokens               * PRICE.output       / 1_000_000) +
      (u.cache_creation_input_tokens * PRICE.cache_write  / 1_000_000) +
      (u.cache_read_input_tokens     * PRICE.cache_read   / 1_000_000)

    const parts = [
      `in ${u.input_tokens.toLocaleString()}`,
      `out ${u.output_tokens.toLocaleString()}`,
    ]
    if (u.cache_read_input_tokens > 0)
      parts.push(`cache hit ${u.cache_read_input_tokens.toLocaleString()}`)
    if (u.cache_creation_input_tokens > 0)
      parts.push(`cache write ${u.cache_creation_input_tokens.toLocaleString()}`)
    parts.push(`$${cost.toFixed(4)}`)

    this.usageTarget.textContent = parts.join(" · ")
    this.usageTarget.classList.remove("hidden")
  }

  // ── Parsing ────────────────────────────────────────────────────────────────

  _parse(text) {
    const fields = {}

    // Extract markdown table rows: | Field | Value |
    const tableRe = /^\|\s*\*\*?([^|*]+)\*\*?\s*\|\s*([^|]*?)\s*\|$/gm
    let m
    while ((m = tableRe.exec(text)) !== null) {
      const key   = m[1].trim().toLowerCase().replace(/\s+/g, "_")
      const value = m[2].trim()
      fields[key] = value
    }

    // Article body: everything from first <p> tag to end of text
    const bodyIdx = text.indexOf("<p")
    fields._body = bodyIdx !== -1 ? text.slice(bodyIdx).trim() : ""

    return fields
  }

  // ── Apply CMS fields ───────────────────────────────────────────────────────

  applyFields() {
    if (!this._parsed) return
    const f = this._parsed

    this._fill("[name$='[title]']",            f.title)
    this._fill("[name$='[subtitle]']",         f.subtitle)
    this._fill("[name$='[excerpt]']",          f.excerpt)
    this._fill("[name$='[meta_description]']", f.meta_description)
    this._fill("[name$='[meta_keywords]']",    f.meta_keywords)
    this._fill("[name$='[reading_time]']",     f.reading_time)

    // Status select — map "Draft" → "draft"
    if (f.status) {
      const sel = document.querySelector("[name$='[status]']")
      if (sel) {
        const target = f.status.toLowerCase()
        const opt = Array.from(sel.options).find(o => o.value === target)
        if (opt) sel.value = opt.value
      }
    }

    this._setStatus("Fields applied")
  }

  _fill(selector, value) {
    if (!value) return
    const el = document.querySelector(selector)
    if (el) el.value = value
  }

  // ── Insert body into Lexxy editor ─────────────────────────────────────────

  insertBody() {
    if (!this._parsed || !this._parsed._body) return

    const lexxy = document.querySelector("lexxy-editor")
    if (!lexxy) {
      this._setStatus("Editor not found", true)
      return
    }

    lexxy.value = this._parsed._body

    // Force a synchronous Lexical commit so internals.setFormValue() is called
    // before Turbo serialises the form — without this the async update races the submit.
    if (lexxy.editor) {
      lexxy.editor.update(() => {}, { skipTransforms: true, discrete: true })
    }

    this._bodyInserted = true
    this._setStatus("Inserted into editor")
  }
}
