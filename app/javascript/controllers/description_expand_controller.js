import { Controller } from "@hotwired/stimulus"

const LIMIT = 200

// Connects to data-controller="description-expand"
// Truncates text to LIMIT chars, adds "See more" button that opens a modal.
// Uses MutationObserver to re-truncate when video-player swaps the description.
export default class extends Controller {
  connect() {
    this._observer = new MutationObserver(() => this._truncate())
    this._truncate()
  }

  disconnect() {
    this._observer.disconnect()
    this._closeModal()
  }

  // ── private ───────────────────────────────────────────────────────────────

  _truncate() {
    // Pause observer to avoid triggering on our own DOM writes
    this._observer.disconnect()

    const full = this.element.textContent.trim()
    if (full.length > LIMIT) {
      this._full = full
      this.element.textContent = full.slice(0, LIMIT) + "…"

      const btn = document.createElement("button")
      btn.type = "button"
      btn.textContent = "See more"
      btn.className = "ml-1 text-sm underline opacity-70 hover:opacity-100 cursor-pointer"
      btn.addEventListener("click", () => this._openModal())
      this.element.appendChild(btn)
    }

    // Resume watching for external text changes (e.g. video-player#switchVideo)
    this._observer.observe(this.element, { childList: true, characterData: true, subtree: true })
  }

  _openModal() {
    this._closeModal()

    const overlay = document.createElement("div")
    overlay.style.cssText = [
      "position:fixed", "inset:0", "z-index:9999",
      "background:rgba(0,0,0,0.75)",
      "display:flex", "align-items:center", "justify-content:center",
      "padding:1rem"
    ].join(";")

    const card = document.createElement("div")
    card.className = "description-modal-card"

    const closeBtn = document.createElement("button")
    closeBtn.type = "button"
    closeBtn.innerHTML = "&times;"
    closeBtn.className = "description-modal-close"
    closeBtn.addEventListener("click", () => this._closeModal())

    const body = document.createElement("p")
    body.style.cssText = "white-space:pre-wrap;line-height:1.75;font-size:0.9rem;margin-top:0.5rem;font-family:inherit;"
    body.textContent = this._full

    card.appendChild(closeBtn)
    card.appendChild(body)
    overlay.appendChild(card)
    overlay.addEventListener("click", e => { if (e.target === overlay) this._closeModal() })

    document.body.appendChild(overlay)
    this._overlay = overlay
    this._onKeydown = e => { if (e.key === "Escape") this._closeModal() }
    document.addEventListener("keydown", this._onKeydown)
  }

  _closeModal() {
    if (this._overlay) {
      this._overlay.remove()
      this._overlay = null
    }
    if (this._onKeydown) {
      document.removeEventListener("keydown", this._onKeydown)
      this._onKeydown = null
    }
  }
}
