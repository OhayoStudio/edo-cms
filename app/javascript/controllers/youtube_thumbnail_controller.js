import { Controller } from "@hotwired/stimulus"

const YOUTUBE_RE = /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/

// Connects to data-controller="youtube-thumbnail"
export default class extends Controller {
  static targets = [ "urlInput", "titleInput", "descriptionInput", "fileInput", "useButton", "flag", "preview", "status" ]
  static values  = { metadataUrl: String }

  connect() {
    this._debounceTimer = null
    this._fetchedId = this._videoId()  // existing record: don't refetch the saved video
    this._autofilled = { title: null, description: null }
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
    if (!id || id === this._fetchedId) return
    this._fetchedId = id

    this._setStatus("loading")
    try {
      // metadataUrlValue already carries ?locale=…, so append rather than concatenate.
      const url = new URL(this.metadataUrlValue, window.location.origin)
      url.searchParams.set("url", `https://www.youtube.com/watch?v=${id}`)
      const resp = await fetch(url, { headers: { "Accept": "application/json" } })
      if (!resp.ok || id !== this._videoId()) return this._setStatus(resp.ok ? null : "error")
      const { title, description } = await resp.json()

      this._fill(this.titleInputTarget, "title", title)
      this._fill(this.descriptionInputTarget, "description", description)
      this._setStatus(title || description ? null : "error")
    } catch (_) {
      this._setStatus("error")
    }
  }

  // Fill when empty or still holding our previous auto-fill; never clobber typed text.
  _fill(input, key, value) {
    if (!value) return
    const current = input.value.trim()
    if (current !== "" && current !== this._autofilled[key]) return
    input.value = value
    this._autofilled[key] = value.trim()
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  _setStatus(state) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget
    el.textContent = state ? el.dataset[state] : ""
    el.classList.toggle("hidden", !state)
  }

  _videoId() {
    const m = this.urlInputTarget.value.match(YOUTUBE_RE)
    return m ? m[1] : null
  }
}
