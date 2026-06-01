import { Controller } from "@hotwired/stimulus"

// Shows the site-wide announcement banner unless the visitor has dismissed it.
// The markup ships hidden so a dismissed banner never flashes; we reveal it
// on connect when there's no stored dismissal. Re-runs on every Turbo
// navigation because the controller reconnects with the new <body>.
const STORAGE_KEY = "edo:announcement-dismissed"

export default class extends Controller {
  static targets = ["root"]

  connect() {
    if (this.#dismissed()) return
    this.rootTarget.classList.remove("hidden")
  }

  dismiss() {
    try {
      localStorage.setItem(STORAGE_KEY, "1")
    } catch (_e) {
      // Private mode / storage disabled — just hide for this session.
    }
    this.rootTarget.classList.add("hidden")
  }

  #dismissed() {
    try {
      return localStorage.getItem(STORAGE_KEY) === "1"
    } catch (_e) {
      return false
    }
  }
}
