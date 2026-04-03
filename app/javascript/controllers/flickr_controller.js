import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flickr"
export default class extends Controller {
  static values = {
    albumsUrl: String,
    importUrl: String,
    articleId: String
  }

  async open() {
    this._showModal("<p class='text-sm text-gray-500'>Loading albums…</p>")

    const resp = await fetch(this.albumsUrlValue)
    if (!resp.ok) {
      this._showModal("<p class='text-sm text-red-500'>Failed to load albums.</p>")
      return
    }

    const albums = await resp.json()
    if (albums.error) {
      this._showModal(`<p class='text-sm text-red-500'>${albums.error}</p>`)
      return
    }

    this._renderAlbums(albums)
  }

  close() {
    const modal = document.getElementById("flickr-modal")
    if (modal) modal.remove()
  }

  // ── private ───────────────────────────────────────────────────────────────

  _showModal(bodyHtml) {
    this.close()
    const modal = document.createElement("div")
    modal.id = "flickr-modal"
    modal.className = "fixed inset-0 z-50 flex items-center justify-center bg-black/60"
    modal.innerHTML = `
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow-xl w-full max-w-3xl max-h-[80vh] flex flex-col overflow-hidden mx-4">
        <div class="flex items-center justify-between px-4 py-3 border-b border-gray-200 dark:border-gray-700">
          <h2 class="text-sm font-medium text-gray-700 dark:text-gray-300">Flickr Albums</h2>
          <button data-action="click->flickr#close" class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 text-lg leading-none">&times;</button>
        </div>
        <div id="flickr-modal-body" class="overflow-y-auto p-4 flex-1">${bodyHtml}</div>
      </div>
    `
    modal.addEventListener("click", e => { if (e.target === modal) this.close() })
    document.body.appendChild(modal)
  }

  _renderAlbums(albums) {
    const grid = albums.map(album => `
      <button type="button"
              class="flex flex-col items-center gap-1 p-2 rounded hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors text-center"
              data-flickr-id="${album.id}"
              data-flickr-title="${album.title}">
        <img src="${album.cover_url}"
             class="w-24 h-24 object-cover rounded border border-gray-200 dark:border-gray-600"
             loading="lazy"
             onerror="this.style.display='none'" />
        <span class="text-xs text-gray-700 dark:text-gray-300 leading-tight max-w-[6rem] line-clamp-2">${album.title}</span>
        <span class="text-[10px] text-gray-400">${album.photo_count} photos</span>
      </button>
    `).join("")

    const body = document.getElementById("flickr-modal-body")
    body.innerHTML = `<div class="grid grid-cols-4 sm:grid-cols-5 md:grid-cols-6 gap-2">${grid}</div>`

    body.querySelectorAll("button[data-flickr-id]").forEach(btn => {
      btn.addEventListener("click", () => this._importAlbum(btn.dataset.flickrId, btn.dataset.flickrTitle))
    })
  }

  async _importAlbum(photosetId, title) {
    this._showModal(`<p class='text-sm text-gray-500'>Importing "${title}"…</p>`)

    const resp = await fetch(this.importUrlValue, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({ article_id: this.articleIdValue, photoset_id: photosetId })
    })

    const result = await resp.json()
    this.close()

    if (!resp.ok) {
      console.error("Flickr import failed:", result.error)
      return
    }

    const panel = document.querySelector("[data-controller~='article-photo-candidates']")
    if (!panel) return
    const ctrl = this.application.getControllerForElementAndIdentifier(panel, "article-photo-candidates")
    if (!ctrl) return
    result.thumbnails.forEach(t => ctrl.addThumbnail(t.url, t.original_url, t.id))
  }
}
