import { Controller } from "@hotwired/stimulus"

// Lucide "zoom-in" icon (circle + crosshair + plus)
const ZOOM_ICON = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"
  fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
  aria-hidden="true">
  <circle cx="11" cy="11" r="8"/>
  <line x1="21" y1="21" x2="16.65" y2="16.65"/>
  <line x1="11" y1="8" x2="11" y2="14"/>
  <line x1="8" y1="11" x2="14" y2="11"/>
</svg>`

// Connects to data-controller="photo-zoom"
// Wraps a lexxy-content div; clicks on any <img> (or its zoom badge) open a fullscreen lightbox.
// Image is displayed at its natural size, capped to 95vw / 92vh (never upscaled).
export default class extends Controller {
  connect() {
    this._onClick   = this._onClick.bind(this)
    this._onKeydown = this._onKeydown.bind(this)
    this.element.addEventListener("click", this._onClick)
    this._decorateImages()
  }

  disconnect() {
    this.element.removeEventListener("click", this._onClick)
    this._closeOverlay()
  }

  // ── private ───────────────────────────────────────────────────────────────

  _decorateImages() {
    this.element.querySelectorAll("img").forEach(img => {
      if (img.dataset.zoomDecorated) return
      img.dataset.zoomDecorated = "1"
      if (img.closest("a")) return   // don't badge linked images

      // Use the closest figure as host, or wrap the img ourselves
      const parent = img.parentElement
      let host
      if (parent.matches("figure, picture")) {
        host = parent
      } else {
        host = document.createElement("span")
        host.className = "photo-zoom-wrap"
        parent.insertBefore(host, img)
        host.appendChild(img)
      }
      host.classList.add("photo-zoom-host")

      const badge = document.createElement("span")
      badge.className = "photo-zoom-badge"
      badge.innerHTML = ZOOM_ICON
      host.appendChild(badge)
    })
  }

  _onClick(event) {
    // Click on the badge → find associated img
    const badge = event.target.closest(".photo-zoom-badge")
    const img   = badge
      ? badge.closest(".photo-zoom-host")?.querySelector("img")
      : event.target.closest("img")

    if (!img) return
    if (img.closest("a")) return
    event.preventDefault()
    this._openOverlay(img.src, img.alt)
  }

  _openOverlay(src, alt) {
    this._closeOverlay()

    const overlay = document.createElement("div")
    overlay.style.cssText = [
      "position:fixed", "inset:0", "z-index:9999",
      "background:rgba(0,0,0,0.88)",
      "display:flex", "align-items:center", "justify-content:center",
      "cursor:zoom-out", "padding:1rem"
    ].join(";")

    const img = document.createElement("img")
    img.src    = src
    img.alt    = alt || ""
    img.style.cssText = [
      "max-width:95vw", "max-height:92vh",
      "width:auto", "height:auto",
      "object-fit:contain",
      "box-shadow:0 8px 48px rgba(0,0,0,0.7)",
      "border-radius:2px"
    ].join(";")

    overlay.appendChild(img)
    overlay.addEventListener("click", () => this._closeOverlay())
    document.addEventListener("keydown", this._onKeydown)
    document.body.appendChild(overlay)
    this._overlay = overlay
  }

  _onKeydown(event) {
    if (event.key === "Escape") this._closeOverlay()
  }

  _closeOverlay() {
    if (this._overlay) {
      this._overlay.remove()
      this._overlay = null
    }
    document.removeEventListener("keydown", this._onKeydown)
  }
}
