import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "chevron", "prompt", "generateBtn", "applyBtn", "insertBtn", "status", "output" ]
  static values  = { draftUrl: String }

  connect() {
    this._accumulated = ""
    this._parsed      = null
    this._source      = null
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
    this.applyBtnTarget.classList.add("hidden")
    this.insertBtnTarget.classList.add("hidden")
    this.generateBtnTarget.disabled = true
    this.statusTarget.textContent = "Thinking…"

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
      const reader = res.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ""

      const pump = () => reader.read().then(({ done, value }) => {
        if (done) {
          this._onStreamEnd()
          return
        }
        buffer += decoder.decode(value, { stream: true })
        const lines = buffer.split("\n")
        buffer = lines.pop()           // keep incomplete line

        for (const line of lines) {
          if (!line.startsWith("data: ")) continue
          const chunk = line.slice(6).replace(/\\n/g, "\n")
          this._accumulated += chunk
          this.outputTarget.textContent = this._accumulated
          this.outputTarget.scrollTop = this.outputTarget.scrollHeight
        }
        this.statusTarget.textContent = "Writing…"
        pump()
      })
      pump()
    }).catch(err => {
      if (err.name !== "AbortError") {
        this.statusTarget.textContent = "Error — see console"
        console.error(err)
      }
    })
  }

  _onStreamEnd() {
    this.generateBtnTarget.disabled = false
    this.statusTarget.textContent = "Done"
    this._parsed = this._parse(this._accumulated)
    this.applyBtnTarget.classList.remove("hidden")
    this.insertBtnTarget.classList.remove("hidden")
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

    // Article body: everything from first <p> to end (or "Unverified" note)
    const bodyMatch = text.match(/<p[\s>][\s\S]*?(?=\n---|\nUnverified|\Z)/i)
    fields._body = bodyMatch ? bodyMatch[0].trim() : ""

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

    this.statusTarget.textContent = "Fields applied"
  }

  _fill(selector, value) {
    if (!value) return
    const el = document.querySelector(selector)
    if (el) el.value = value
  }

  // ── Insert body into Lexxy / Trix editor ──────────────────────────────────

  insertBody() {
    if (!this._parsed || !this._parsed._body) return

    const trix = document.querySelector("trix-editor")
    if (!trix || !trix.editor) {
      this.statusTarget.textContent = "Trix editor not found"
      return
    }

    // Select all and replace
    const doc = trix.editor.getDocument()
    trix.editor.setSelectedRange([ 0, doc.toString().length ])
    trix.editor.deleteInDirection("forward")
    trix.editor.insertHTML(this._parsed._body)
    this.statusTarget.textContent = "Inserted into editor"
  }
}
