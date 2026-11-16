import { Controller } from "@hotwired/stimulus"

// Clones a row's <template id="video-preview-ID"> into the modal; clearing it on close stops playback.
export default class extends Controller {
  static targets = ["modal", "title", "body"]

  open(event) {
    event.preventDefault()
    const { videoId, videoTitle } = event.currentTarget.dataset
    const tpl = document.getElementById(`video-preview-${videoId}`)
    if (!tpl) return

    this.titleTarget.textContent = videoTitle
    this.bodyTarget.replaceChildren(tpl.content.cloneNode(true))
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    document.body.style.overflow = "hidden"
    this._opener = event.currentTarget
    this.modalTarget.querySelector("[data-video-preview-close]")?.focus()
  }

  close() {
    if (this.modalTarget.classList.contains("hidden")) return
    this.bodyTarget.replaceChildren()
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    document.body.style.overflow = ""
    this._opener?.focus()
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }
}
