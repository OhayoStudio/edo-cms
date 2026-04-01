import { Controller } from "@hotwired/stimulus"

const DRAG_TYPE = "application/x-photo-candidate"

// Connects to data-controller="article-photo-candidates"
export default class extends Controller {
  static targets = ["input", "previews"]

  connect() {
    this._editorEl = this.element.closest("form")?.querySelector("lexxy-editor")
    if (this._editorEl) {
      this._editorEl.addEventListener("dragover", this._onEditorDragOver)
      this._editorEl.addEventListener("drop", this._onEditorDrop)
    }
  }

  disconnect() {
    if (this._editorEl) {
      this._editorEl.removeEventListener("dragover", this._onEditorDragOver)
      this._editorEl.removeEventListener("drop", this._onEditorDrop)
    }
  }

  uploadFiles(event) {
    const files = event.target.files
    if (!files.length) return
    Array.from(files).forEach(file => this.uploadFile(file))
    // Clear input so same file can be re-uploaded
    event.target.value = ""
  }

  uploadFile(file) {
    const articleId = this.element.dataset.articleId
    const formData = new FormData()
    formData.append("photo_candidate", file)
    fetch(`/admin/articles/${articleId}/direct_upload_photo_candidate`, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content },
      body: formData
    })
      .then(response => response.json())
      .then(data => {
        if (data.url) {
          this.addThumbnail(data.url, data.original_url)
        }
      })
  }

  addThumbnail(thumbUrl, originalUrl) {
    const img = document.createElement("img")
    img.src = thumbUrl
    img.className = "object-cover w-24 h-24 rounded border bg-white m-1 cursor-pointer hover:ring-2 hover:ring-[#704214]"
    img.title = "Click to insert at cursor · Drag to position"
    if (originalUrl) {
      img.dataset.originalUrl = originalUrl
      img.draggable = true
      img.addEventListener("dragstart", this._onImgDragStart)
      img.addEventListener("click", (e) => this.onThumbnailClick(e))
    }
    this.previewsTarget.appendChild(img)
  }

  onThumbnailDragStart(event) {
    const originalUrl = event.target.dataset.originalUrl
    if (!originalUrl) return
    event.dataTransfer.setData(DRAG_TYPE, originalUrl)
    event.dataTransfer.effectAllowed = "copy"
  }

  async onThumbnailClick(event) {
    const originalUrl = event.currentTarget.dataset.originalUrl
    if (!originalUrl || !this._editorEl) return

    // Focus editor to restore last cursor position
    const ce = this._editorEl.querySelector("[contenteditable]")
    if (ce) ce.focus()

    try {
      const resp = await fetch(originalUrl)
      const blob = await resp.blob()
      const filename = originalUrl.split("/").pop().split("?")[0] || "image.jpg"
      const file = new File([ blob ], filename, { type: blob.type || "image/jpeg" })
      requestAnimationFrame(() => {
        this._editorEl.contents.uploadFiles([ file ], { selectLast: true })
      })
    } catch (err) {
      console.error("Photo candidate click insert failed:", err)
    }
  }

  _onImgDragStart = (event) => {
    const originalUrl = event.target.dataset.originalUrl
    if (!originalUrl) return
    event.dataTransfer.setData(DRAG_TYPE, originalUrl)
    event.dataTransfer.effectAllowed = "copy"
  }

  _onEditorDragOver = (event) => {
    if (!event.dataTransfer.types.includes(DRAG_TYPE)) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }

  _onEditorDrop = async (event) => {
    const originalUrl = event.dataTransfer.getData(DRAG_TYPE)
    if (!originalUrl) return
    // Don't preventDefault/stopPropagation — Lexky's inner handler already ran
    // (bubbling: contenteditable fires first, then lexxy-editor) and restored the
    // caret position via #restoreSelectionBeforeDrag before returning.

    try {
      const resp = await fetch(originalUrl)
      const blob = await resp.blob()
      const filename = originalUrl.split("/").pop().split("?")[0] || "image.jpg"
      const file = new File([ blob ], filename, { type: blob.type || "image/jpeg" })

      this._editorEl.contents.uploadFiles([ file ], { selectLast: true })
    } catch (err) {
      console.error("Photo candidate drop failed:", err)
    }
  }
}
