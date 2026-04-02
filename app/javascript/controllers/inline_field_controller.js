import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inline-field"
// Renders a label that, when clicked, swaps to a <select>.
// On change it PATCHes the value and reverts to label. Escape cancels.
export default class extends Controller {
  static targets = ["label", "select"]
  static values  = { url: String, field: String }

  show() {
    this.labelTarget.classList.add("hidden")
    this.selectTarget.classList.remove("hidden")
    this.selectTarget.focus()
  }

  hide() {
    this.selectTarget.classList.add("hidden")
    this.labelTarget.classList.remove("hidden")
  }

  async change() {
    const value = this.selectTarget.value
    const label = this.selectTarget.options[this.selectTarget.selectedIndex].text

    const resp = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({ field: this.fieldValue, value })
    })

    if (resp.ok) {
      this.labelTarget.textContent = label
    }
    this.hide()
  }

  keydown(event) {
    if (event.key === "Escape") this.hide()
  }
}
