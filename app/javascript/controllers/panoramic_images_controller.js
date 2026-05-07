import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "content", "pageInfo", "prevBtn", "nextBtn" ]

  connect() {
    this.currentPage = 1
    this.perPage = 10
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    this.currentPage = 1
    this.loadImages()
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  async loadImages() {
    this.contentTarget.innerHTML = `<p class="text-sm text-gray-500 dark:text-gray-400 text-center py-8">Loading…</p>`

    try {
      const url = `/admin/panoramic_images.json?page=${this.currentPage}&per_page=${this.perPage}`
      const response = await fetch(url, {
        credentials: "same-origin",
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()
      const items = data.panoramic_images || []

      if (items.length === 0) {
        this.contentTarget.innerHTML = `<p class="text-sm text-gray-500 dark:text-gray-400 text-center py-8">No panoramic images found.</p>`
      } else {
        const escAttr = (s) => String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        this.contentTarget.innerHTML = items.map(img => `
          <div class="flex items-center gap-3 py-2 border-b border-gray-100 dark:border-gray-700 last:border-0">
            <span class="text-xs font-mono text-gray-500 dark:text-gray-400 w-10">#${img.id}</span>
            <img src="${escAttr(img.image_url)}" alt="" class="h-12 w-20 object-cover rounded border border-gray-200 dark:border-gray-600" />
            <button type="button"
                    data-action="click->panoramic-images#insertImage"
                    data-sgid="${escAttr(img.sgid)}"
                    data-content-type="${escAttr(img.content_type)}"
                    data-content="${escAttr(JSON.stringify(img.content))}"
                    class="ml-auto px-2 py-1 text-xs bg-amber-600 hover:bg-amber-700 text-white rounded">
              Insert where cursor is
            </button>
          </div>
        `).join("")
      }

      this.pageInfoTarget.textContent = `Page ${this.currentPage}`
      this.prevBtnTarget.disabled = this.currentPage === 1
      this.nextBtnTarget.disabled = !data.has_more
    } catch (err) {
      console.error("[panoramic-images] load failed:", err)
      this.contentTarget.innerHTML = `<p class="text-sm text-red-500 text-center py-8">Failed to load: ${err.message}</p>`
    }
  }

  insertImage(event) {
    const ds = event.currentTarget.dataset
    // Build attachment element programmatically so attribute escaping is correct.
    const attachment = document.createElement("action-text-attachment")
    attachment.setAttribute("sgid", ds.sgid)
    attachment.setAttribute("content-type", ds.contentType)
    attachment.setAttribute("content", ds.content) // already JSON-stringified server side
    const html = attachment.outerHTML

    const editor = this.element.querySelector("lexxy-editor")
    if (editor && editor.contents) {
      editor.focus()
      editor.contents.insertHtml(html)
      this.close()
    } else {
      console.error("[panoramic-images] lexxy editor not found", { editor })
      alert("Could not find the editor.")
    }
  }

  nextPage() {
    this.currentPage++
    this.loadImages()
  }

  prevPage() {
    if (this.currentPage > 1) {
      this.currentPage--
      this.loadImages()
    }
  }
}
