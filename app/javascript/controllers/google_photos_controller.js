import { Controller } from "@hotwired/stimulus"

const DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.file"

// Connects to data-controller="google-photos"
export default class extends Controller {
  static values = {
    clientId: String,
    apiKey:   String,
    importUrl: String,
    articleId: String
  }

  connect() {
    this._accessToken = null
    this._tokenClient = null
    this._pickerReady = false
  }

  async open() {
    await this._loadLibraries()
    this._requestToken()
  }

  // ── private ───────────────────────────────────────────────────────────────

  async _loadLibraries() {
    if (!window.gapi) {
      await this._loadScript("https://apis.google.com/js/api.js")
    }
    if (!window.google?.accounts?.oauth2) {
      await this._loadScript("https://accounts.google.com/gsi/client")
    }
    if (!this._pickerReady) {
      await new Promise(resolve => gapi.load("picker", resolve))
      this._pickerReady = true
    }
  }

  _loadScript(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement("script")
      s.src = src
      s.onload = resolve
      s.onerror = reject
      document.head.appendChild(s)
    })
  }

  _requestToken() {
    if (!this._tokenClient) {
      this._tokenClient = google.accounts.oauth2.initTokenClient({
        client_id: this.clientIdValue,
        scope: DRIVE_SCOPE,
        callback: resp => {
          if (resp.error) return
          this._accessToken = resp.access_token
          this._showPicker()
        }
      })
    }
    if (this._accessToken) {
      this._showPicker()
    } else {
      this._tokenClient.requestAccessToken()
    }
  }

  _showPicker() {
    const picker = new google.picker.PickerBuilder()
      .addView(new google.picker.PhotosView())
      .addView(new google.picker.PhotosView().setType(google.picker.PhotosView.Type.ALBUMS))
      .addView(new google.picker.DocsView(google.picker.ViewId.DOCS_IMAGES))
      .enableFeature(google.picker.Feature.MULTISELECT_ENABLED)
      .setOAuthToken(this._accessToken)
      .setDeveloperKey(this.apiKeyValue)
      .setCallback(data => this._onPick(data))
      .build()
    picker.setVisible(true)
  }

  async _onPick(data) {
    if (data[google.picker.Response.ACTION] !== google.picker.Action.PICKED) return

    const photos = data[google.picker.Response.DOCUMENTS].map(doc => ({
      file_id:   doc[google.picker.Document.ID],
      filename:  doc[google.picker.Document.NAME],
      mime_type: doc[google.picker.Document.MIME_TYPE]
    }))

    const resp = await fetch(this.importUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({
        article_id:   this.articleIdValue,
        access_token: this._accessToken,
        photos
      })
    })

    const result = await resp.json()
    if (!resp.ok) {
      console.error("Google Photos import failed:", result.error)
      return
    }

    const panel = document.querySelector("[data-controller~='article-photo-candidates']")
    if (!panel) return
    const ctrl = this.application.getControllerForElementAndIdentifier(panel, "article-photo-candidates")
    if (!ctrl) return
    result.thumbnails.forEach(t => ctrl.addThumbnail(t.url, t.original_url, t.id))
  }
}
