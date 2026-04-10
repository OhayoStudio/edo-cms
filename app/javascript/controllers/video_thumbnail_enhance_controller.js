import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="video-thumbnail-enhance"
export default class extends Controller {
  static targets = [ "prompt", "enhanceBtn", "icon", "status", "grid", "featuredPreview" ]
  static values  = { enhanceUrl: String, promoteUrl: String, destroyUrl: String }

  // ── AI enhance ─────────────────────────────────────────────────────────────

  async enhance() {
    const prompt = this.promptTarget.value.trim()
    if (!prompt) return

    this.enhanceBtnTarget.disabled = true
    this.iconTarget.classList.add("animate-spin")
    this._setStatus("Enhancing… this may take ~15s")

    try {
      const res = await fetch(this.enhanceUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrf()
        },
        body: JSON.stringify({ prompt })
      })

      const json = await res.json()
      if (!res.ok) throw new Error(json.error || `HTTP ${res.status}`)

      this._appendCard(json.id, json.url)
      this._setStatus("Done")
    } catch (e) {
      this._setStatus(`Error: ${e.message}`, true)
    } finally {
      this.enhanceBtnTarget.disabled = false
      this.iconTarget.classList.remove("animate-spin")
    }
  }

  // ── Promote to featured ────────────────────────────────────────────────────

  async promote(e) {
    const card         = e.currentTarget.closest("[data-attachment-id]")
    const attachmentId = card.dataset.attachmentId

    try {
      const res = await fetch(this.promoteUrlValue, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this._csrf()
        },
        body: JSON.stringify({ attachment_id: attachmentId })
      })

      const json = await res.json()
      if (!res.ok) throw new Error(json.error || `HTTP ${res.status}`)

      if (this.hasFeaturedPreviewTarget) {
        this.featuredPreviewTarget.src = json.url
      }
      this._setStatus("Featured image updated")
    } catch (e) {
      this._setStatus(`Error: ${e.message}`, true)
    }
  }

  // ── Delete candidate ───────────────────────────────────────────────────────

  async destroy(e) {
    const card         = e.currentTarget.closest("[data-attachment-id]")
    const attachmentId = card.dataset.attachmentId

    try {
      const res = await fetch(`${this.destroyUrlValue}?attachment_id=${attachmentId}`, {
        method:  "DELETE",
        headers: { "X-CSRF-Token": this._csrf() }
      })

      if (res.ok || res.status === 204) {
        card.remove()
      } else {
        this._setStatus("Delete failed", true)
      }
    } catch (e) {
      this._setStatus(`Error: ${e.message}`, true)
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  _appendCard(id, url) {
    const card = document.createElement("div")
    card.className = "relative group"
    card.dataset.attachmentId = id
    card.innerHTML = `
      <img src="${url}" class="w-40 h-[90px] object-cover rounded border border-gray-200 dark:border-gray-600" />
      <button type="button"
              data-action="click->video-thumbnail-enhance#destroy"
              class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-red-500 hover:bg-red-600 text-white
                     rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100
                     transition-opacity shadow text-xs font-bold">✕</button>
      <button type="button"
              data-action="click->video-thumbnail-enhance#promote"
              class="absolute bottom-1 left-1 right-1 text-xs bg-black/60 hover:bg-black/80 text-white
                     rounded py-0.5 text-center opacity-0 group-hover:opacity-100 transition-opacity">
        Set as Featured
      </button>
    `
    this.gridTarget.appendChild(card)
  }

  _setStatus(msg, isError = false) {
    this.statusTarget.textContent = msg
    this.statusTarget.classList.toggle("text-red-500", isError)
    this.statusTarget.classList.toggle("text-gray-400", !isError)
  }

  _csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
