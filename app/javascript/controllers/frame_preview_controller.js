import { Controller } from "@hotwired/stimulus"

// Opens a same-origin page (e.g. an article preview) in the modal's iframe.
// The iframe loads data-preview-frame-url (bare page) when set; modifier/middle
// clicks and "open in a new tab" use the link's full-page href.
export default class extends Controller {
  static targets = ["modal", "title", "frame", "external"]

  open(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button === 1) return
    event.preventDefault()
    const link = event.currentTarget
    const title = link.dataset.previewTitle || ""

    this.titleTarget.textContent = title
    this.frameTarget.title = title
    this.frameTarget.src = link.dataset.previewFrameUrl || link.href
    if (this.hasExternalTarget) this.externalTarget.href = link.href
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    document.body.style.overflow = "hidden"
    this._opener = link
    this.modalTarget.querySelector("[data-frame-preview-close]")?.focus()
  }

  close() {
    if (this.modalTarget.classList.contains("hidden")) return
    this.frameTarget.src = "about:blank"
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    document.body.style.overflow = ""
    this._opener?.focus()
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }
}
