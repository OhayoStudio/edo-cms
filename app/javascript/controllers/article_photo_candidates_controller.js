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

  get _articleId() {
    return this.element.dataset.articleId || null
  }

  _requireSaved() {
    if (this._articleId) return true
    this._showError("Save the article first before adding photos.")
    return false
  }

  _showError(msg) {
    const existing = this.element.querySelector(".photo-candidate-error")
    if (existing) { existing.textContent = msg; return }
    const el = document.createElement("p")
    el.className = "photo-candidate-error text-xs text-red-500 dark:text-red-400 mt-1"
    el.textContent = msg
    this.inputTarget.insertAdjacentElement("afterend", el)
    setTimeout(() => el.remove(), 4000)
  }

  uploadFiles(event) {
    const files = event.target.files
    if (!files.length) return
    if (!this._requireSaved()) { event.target.value = ""; return }
    Array.from(files).forEach(file => this.uploadFile(file))
    // Clear input so same file can be re-uploaded
    event.target.value = ""
  }

  uploadFile(file) {
    const articleId = this._articleId
    if (!articleId) { this._showError("Save the article first before adding photos."); return }
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
          this.addThumbnail(data.url, data.original_url, data.id)
        } else if (data.error) {
          alert(data.error)
        }
      })
  }

  addThumbnail(thumbUrl, originalUrl, attachmentId) {
    const wrapper = document.createElement("div")
    wrapper.className = "relative m-1 group"
    if (attachmentId) wrapper.dataset.attachmentId = attachmentId

    const img = document.createElement("img")
    img.src = thumbUrl
    img.className = "object-cover w-24 h-24 rounded border bg-white cursor-pointer hover:ring-2 hover:ring-[#704214]"
    img.title = "Click to insert at cursor · Drag to position"
    if (originalUrl) {
      img.dataset.originalUrl = originalUrl
      img.draggable = true
      img.addEventListener("dragstart", this._onImgDragStart)
      img.addEventListener("click", (e) => this.onThumbnailClick(e))
    }
    wrapper.appendChild(img)

    if (attachmentId) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.title = "Delete photo"
      btn.className = "absolute -top-1.5 -right-1.5 w-5 h-5 bg-red-500 hover:bg-red-600 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity shadow"
      btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`
      btn.addEventListener("click", (e) => this.deletePhoto(e))
      wrapper.appendChild(btn)
    }

    this.previewsTarget.appendChild(wrapper)
  }

  onThumbnailDragStart(event) {
    const originalUrl = event.target.closest("img")?.dataset.originalUrl
    if (!originalUrl) return
    event.dataTransfer.setData(DRAG_TYPE, originalUrl)
    event.dataTransfer.effectAllowed = "copy"
  }

  // Zone-level drag-over: accept filesystem files dropped directly onto the candidates panel
  zoneDragover(event) {
    if (!event.dataTransfer.types.includes("Files")) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
    this.element.classList.add("ring-2", "ring-[#704214]")
  }

  zoneDragleave() {
    this.element.classList.remove("ring-2", "ring-[#704214]")
  }

  zoneDrop(event) {
    if (!event.dataTransfer.types.includes("Files")) return
    event.preventDefault()
    this.element.classList.remove("ring-2", "ring-[#704214]")
    if (!this._requireSaved()) return
    Array.from(event.dataTransfer.files).forEach(file => this.uploadFile(file))
  }

  async onThumbnailClick(event) {
    const originalUrl = event.target.closest("img")?.dataset.originalUrl
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

  async deletePhoto(event) {
    const wrapper = event.currentTarget.closest("[data-attachment-id]")
    if (!wrapper) return
    const attachmentId = wrapper.dataset.attachmentId
    const articleId = this._articleId

    const resp = await fetch(
      `/admin/articles/${articleId}/destroy_photo_candidate?attachment_id=${attachmentId}`,
      {
        method: "DELETE",
        headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content }
      }
    )
    if (resp.ok) wrapper.remove()
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
