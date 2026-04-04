import { Controller } from "@hotwired/stimulus"

const YOUTUBE_RE = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/

// Connects to data-controller="youtube-thumbnail"
export default class extends Controller {
  static targets = [ "urlInput", "titleInput", "descriptionInput", "fileInput", "useButton", "flag", "preview" ]
  static values  = { metadataUrl: String }

  connect() {
    this._debounceTimer = null
    this._refresh()
    this.urlInputTarget.addEventListener("input", () => {
      this._refresh()
      this._scheduleFetch()
    })
  }

  use() {
    const id = this._videoId()
    if (!id) return

    this.flagTarget.value = "1"
    this.fileInputTarget.removeAttribute("required")
    this.fileInputTarget.closest("div").style.opacity = "0.4"
    this.useButtonTarget.textContent = "✓ YouTube thumbnail will be used"
    this.useButtonTarget.disabled = true

    this.previewTarget.src = `https://img.youtube.com/vi/${id}/mqdefault.jpg`
    this.previewTarget.classList.remove("hidden")
  }

  // ── private ───────────────────────────────────────────────────────────────

  _refresh() {
    const visible = !!this._videoId()
    this.useButtonTarget.classList.toggle("hidden", !visible)
  }

  _scheduleFetch() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._fetchMetadata(), 600)
  }

  async _fetchMetadata() {
    const id = this._videoId()
    if (!id) return

    try {
      const url = `${this.metadataUrlValue}?url=https://www.youtube.com/watch?v=${id}`
      const resp = await fetch(url, {
        headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content }
      })
      if (!resp.ok) return
      const { title, description } = await resp.json()

      if (title && this.titleInputTarget.value.trim() === "")
        this.titleInputTarget.value = title

      if (description && this.descriptionInputTarget.value.trim() === "")
        this.descriptionInputTarget.value = description
    } catch (_) { /* network error — silently ignore */ }
  }

  _videoId() {
    const m = this.urlInputTarget.value.match(YOUTUBE_RE)
    return m ? m[1] : null
  }
}
