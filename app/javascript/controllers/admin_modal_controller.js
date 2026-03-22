import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url:   String,
    title: String
  }

  open() {
    document.getElementById("admin-modal-title").textContent = this.titleValue
    document.getElementById("admin-modal-form").action = this.urlValue
    document.getElementById("admin-confirm-modal").classList.remove("hidden")
  }

  close() {
    document.getElementById("admin-confirm-modal").classList.add("hidden")
  }

  connect() {
    document.getElementById("admin-modal-cancel")?.addEventListener("click", () => this.close())
  }
}
