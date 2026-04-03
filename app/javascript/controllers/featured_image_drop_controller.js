import { Controller } from "@hotwired/stimulus"

const DRAG_TYPE = "application/x-photo-candidate"

// Connects to data-controller="featured-image-drop"
export default class extends Controller {
  static targets = [ "input", "preview", "hint" ]

  dragover(event) {
    if (!event.dataTransfer.types.includes(DRAG_TYPE)) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
    this.element.classList.add("ring-2", "ring-[#704214]")
  }

  dragleave() {
    this.element.classList.remove("ring-2", "ring-[#704214]")
  }

  async drop(event) {
    if (!event.dataTransfer.types.includes(DRAG_TYPE)) return
    event.preventDefault()
    this.element.classList.remove("ring-2", "ring-[#704214]")

    const originalUrl = event.dataTransfer.getData(DRAG_TYPE)
    if (!originalUrl) return

    try {
      const resp = await fetch(originalUrl)
      const blob = await resp.blob()
      const filename = originalUrl.split("/").pop().split("?")[0] || "featured.jpg"
      const file = new File([ blob ], filename, { type: blob.type || "image/jpeg" })

      const dt = new DataTransfer()
      dt.items.add(file)
      this.inputTarget.files = dt.files

      // Update preview
      const reader = new FileReader()
      reader.onload = e => {
        this.previewTarget.src = e.target.result
        this.previewTarget.classList.remove("hidden")
        this.hintTarget.classList.add("hidden")
      }
      reader.readAsDataURL(file)
    } catch (err) {
      console.error("Featured image drop failed:", err)
    }
  }
}
