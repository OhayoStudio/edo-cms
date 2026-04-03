import { Controller } from "@hotwired/stimulus"

const PHOTOS_SCOPE = "https://www.googleapis.com/auth/photospicker.mediaitems.readonly"

// Connects to data-controller="google-photos"
export default class extends Controller {
  static values = {
    clientId:  String,
    openUrl:   String,
    importUrl: String,
    articleId: String
  }

  connect() {
    this._accessToken = null
    this._tokenClient = null
  }

  async open() {
    if (!window.google?.accounts?.oauth2) {
      await this._loadScript("https://accounts.google.com/gsi/client")
    }
    this._requestToken()
  }

  // ── private ───────────────────────────────────────────────────────────────

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
        scope:     PHOTOS_SCOPE,
        prompt:    "select_account",
        callback:  resp => {
          if (resp.error) return
          this._accessToken = resp.access_token
          this._openPicker()
        }
      })
    }
    if (this._accessToken) {
      this._openPicker()
    } else {
      this._tokenClient.requestAccessToken()
    }
  }

  async _openPicker() {
    const resp = await fetch(this.openUrlValue, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({ access_token: this._accessToken })
    })

    const { session_id, picker_uri, error } = await resp.json()
    if (!resp.ok) {
      console.error("Google Photos session error:", error)
      return
    }

    const popup = window.open(picker_uri + "/autoclose", "_blank", "width=900,height=700")
    this._pollSession(popup, session_id)
  }

  _pollSession(popup, sessionId) {
    let attempts = 0
    let popupClosedAttempt = null
    const GRACE_ATTEMPTS = 6 // 30s grace period after popup closes

    const interval = setInterval(async () => {
      attempts++
      if (attempts > 60) { clearInterval(interval); return } // 5-minute hard timeout

      if (popup.closed && popupClosedAttempt === null) popupClosedAttempt = attempts

      // Give up if popup closed and grace period exhausted
      if (popupClosedAttempt !== null && (attempts - popupClosedAttempt) >= GRACE_ATTEMPTS) {
        clearInterval(interval)
        return
      }

      try {
        const resp = await fetch(
          `https://photospicker.googleapis.com/v1/sessions/${sessionId}`,
          { headers: { "Authorization": `Bearer ${this._accessToken}` } }
        )
        if (!resp.ok) { clearInterval(interval); return }
        const data = await resp.json()
        console.log("[google-photos] session poll:", data.mediaItemsSet, "attempt", attempts)
        if (data.mediaItemsSet) {
          clearInterval(interval)
          await this._import(sessionId)
        }
      } catch (e) {
        clearInterval(interval)
      }
    }, 5000)
  }

  async _import(sessionId) {
    const resp = await fetch(this.importUrlValue, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({
        article_id:   this.articleIdValue,
        access_token: this._accessToken,
        session_id:   sessionId
      })
    })

    const result = await resp.json()
    console.log("[google-photos] import result:", result)
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
