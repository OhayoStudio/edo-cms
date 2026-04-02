import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url:   String,
    title: String,
    row:   String
  }

  connect() {
    document.getElementById("admin-modal-cancel")?.addEventListener("click", () => this.close())
    document.getElementById("admin-modal-form")?.addEventListener("submit", this._onConfirm)
  }

  disconnect() {
    document.getElementById("admin-modal-form")?.removeEventListener("submit", this._onConfirm)
  }

  open() {
    document.getElementById("admin-modal-title").textContent = this.titleValue
    document.getElementById("admin-modal-form").action = this.urlValue
    document.getElementById("admin-confirm-modal").dataset.pendingRow = this.rowValue
    document.getElementById("admin-confirm-modal").classList.remove("hidden")
  }

  close() {
    document.getElementById("admin-confirm-modal").classList.add("hidden")
  }

  _onConfirm = async (event) => {
    event.preventDefault()
    const form = event.currentTarget
    const rowId = document.getElementById("admin-confirm-modal").dataset.pendingRow

    const resp = await fetch(form.action, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content,
        "Accept": "application/json"
      }
    })

    if (resp.ok || resp.redirected) {
      if (rowId) document.getElementById(rowId)?.remove()
      this.close()
    }
  }
}
