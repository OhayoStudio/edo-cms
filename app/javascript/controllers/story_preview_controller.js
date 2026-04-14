import { Controller } from "@hotwired/stimulus"

// Preview frame fixed dimensions (must match CSS)
const FRAME_W = 360
const FRAME_H = 640

export default class extends Controller {
  static targets = ["modal", "frame", "image", "zoom", "gradient", "gradientOverlay", "shareStatus", "shareImageBtn", "shareVideoBtn"]
  static values  = { downloadUrl: String, imageUrl: String, videoUrl: String, shareUrl: String }

  connect() {
    this.dragging    = false
    this.scale       = 1
    this.currentLeft = 0
    this.currentTop  = 0
  }

  // ── Modal ─────────────────────────────────────────────────────────────────

  open() {
    this.modalTarget.style.display = "flex"
    document.body.style.overflow   = "hidden"
    this._clearShareStatus()
    // Defer so the browser has rendered the modal before we read image dims
    requestAnimationFrame(() => this.initImage())
  }

  close() {
    this.modalTarget.style.display = "none"
    document.body.style.overflow   = ""
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  // ── Image init ────────────────────────────────────────────────────────────

  initImage() {
    const img  = this.imageTarget
    const init = () => {
      this.nw  = img.naturalWidth
      this.nh  = img.naturalHeight

      // "Contain" scale: fit the whole image inside the frame
      this.scale = Math.min(FRAME_W / this.nw, FRAME_H / this.nh)

      if (this.hasZoomTarget) this.zoomTarget.value = 100

      // Center the image in the frame
      this.currentLeft = (FRAME_W - this.nw * this.scale) / 2
      this.currentTop  = (FRAME_H - this.nh * this.scale) / 2

      this.applyTransform()
    }

    // naturalWidth is 0 if not yet loaded
    img.complete && img.naturalWidth > 0
      ? init()
      : img.addEventListener("load", init, { once: true })
  }

  applyTransform() {
    const img  = this.imageTarget
    const imgW = this.nw * this.scale
    const imgH = this.nh * this.scale

    img.style.width  = `${imgW}px`
    img.style.height = `${imgH}px`
    img.style.left   = `${this.currentLeft}px`
    img.style.top    = `${this.currentTop}px`
  }

  // ── Drag ──────────────────────────────────────────────────────────────────

  startDrag(event) {
    event.preventDefault()
    this.dragging = true
    this.imageTarget.style.cursor = "grabbing"

    const p      = event.touches ? event.touches[0] : event
    this.originX = p.clientX - this.currentLeft
    this.originY = p.clientY - this.currentTop

    this._onMove = this.onDrag.bind(this)
    this._onStop = this.stopDrag.bind(this)
    window.addEventListener("mousemove", this._onMove)
    window.addEventListener("mouseup",   this._onStop)
    window.addEventListener("touchmove", this._onMove, { passive: false })
    window.addEventListener("touchend",  this._onStop)
  }

  onDrag(event) {
    if (!this.dragging) return
    event.preventDefault()
    const p          = event.touches ? event.touches[0] : event
    this.currentLeft = p.clientX - this.originX
    this.currentTop  = p.clientY - this.originY
    this.applyTransform()
  }

  stopDrag() {
    this.dragging = false
    this.imageTarget.style.cursor = "grab"
    window.removeEventListener("mousemove", this._onMove)
    window.removeEventListener("mouseup",   this._onStop)
    window.removeEventListener("touchmove", this._onMove)
    window.removeEventListener("touchend",  this._onStop)
  }

  // ── Zoom ──────────────────────────────────────────────────────────────────

  onGradient() {
    const opacity = (this.gradientTarget.value / 100).toFixed(2)
    this.gradientOverlayTarget.style.background =
      `linear-gradient(to top, transparent 35%, rgba(0,0,0,${opacity}))`
  }

  onZoom(event) {
    const prevScale  = this.scale
    // Slider 100–350 maps to 1x–3.5x the contain scale
    const containScale = Math.min(FRAME_W / this.nw, FRAME_H / this.nh)
    this.scale = containScale * (parseInt(event.target.value) / 100)

    // Keep the frame centre fixed on the image while zooming
    const ratio      = this.scale / prevScale
    const cx         = FRAME_W / 2 - this.currentLeft
    const cy         = FRAME_H / 2 - this.currentTop
    this.currentLeft = FRAME_W / 2 - cx * ratio
    this.currentTop  = FRAME_H / 2 - cy * ratio

    this.applyTransform()
  }

  // ── Download ──────────────────────────────────────────────────────────────

  positionParams() {
    const scaleToActual = 1080 / FRAME_W
    return {
      img_w: Math.round(this.nw * this.scale * scaleToActual),
      img_h: Math.round(this.nh * this.scale * scaleToActual),
      img_x: Math.round(this.currentLeft * scaleToActual),
      img_y: Math.round(this.currentTop  * scaleToActual),
      gradient_opacity: this.hasGradientTarget ? this.gradientTarget.value : 55,
    }
  }

  buildUrl(base, extra = {}) {
    const url = new URL(base, window.location.origin)
    Object.entries({ ...this.positionParams(), ...extra }).forEach(([ k, v ]) => url.searchParams.set(k, v))
    return url.toString()
  }

  download() {
    window.location.href = this.buildUrl(this.imageUrlValue || this.downloadUrlValue)
  }

  downloadVideo() {
    window.location.href = this.buildUrl(this.videoUrlValue)
  }

  // ── Share to Instagram ────────────────────────────────────────────────────

  shareImage() {
    this._share("image")
  }

  shareVideo() {
    this._share("video")
  }

  async _share(mediaType) {
    const btn = mediaType === "video" ? this.shareVideoBtnTarget : this.shareImageBtnTarget
    const originalText = btn.textContent

    this._setShareStatus("loading", mediaType === "video"
      ? "Generating & uploading MP4… this may take up to a minute."
      : "Generating & sharing PNG…")
    btn.disabled = true

    try {
      const url  = this.buildUrl(this.shareUrlValue, { media_type: mediaType })
      const resp = await fetch(url, {
        method: "POST",
        headers: { "X-CSRF-Token": this._csrfToken() }
      })
      const data = await resp.json()

      if (data.success) {
        this._setShareStatus("success", "Shared to Instagram!")
      } else {
        this._setShareStatus("error", data.error || "Something went wrong.")
      }
    } catch (e) {
      this._setShareStatus("error", `Network error: ${e.message}`)
    } finally {
      btn.disabled    = false
      btn.textContent = originalText
    }
  }

  _setShareStatus(type, message) {
    const el = this.shareStatusTarget
    el.textContent = message
    el.className   = "text-sm rounded-lg px-3 py-2 " + {
      loading: "bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300",
      success: "bg-green-50 dark:bg-green-900/40 text-green-700 dark:text-green-300",
      error:   "bg-red-50 dark:bg-red-900/40 text-red-700 dark:text-red-300"
    }[type]
    el.classList.remove("hidden")
  }

  _clearShareStatus() {
    if (this.hasShareStatusTarget) {
      this.shareStatusTarget.classList.add("hidden")
      this.shareStatusTarget.textContent = ""
    }
  }

  _csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content ?? ""
  }
}
