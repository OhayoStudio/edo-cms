import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="inline-number"
// Renders a label that, when clicked, swaps to a number <input>.
// Enter/blur saves via PATCH; Escape cancels.
export default class extends Controller {
  static targets = [ "label", "input" ]
  static values  = { url: String, field: String }

  show() {
    this.labelTarget.classList.add("hidden")
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  hide() {
    this.inputTarget.classList.add("hidden")
    this.labelTarget.classList.remove("hidden")
  }

  async save() {
    const value = parseInt(this.inputTarget.value, 10)
    if (isNaN(value)) { this.hide(); return }

    const resp = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({ field: this.fieldValue, value })
    })

    if (resp.ok) this.labelTarget.textContent = value
    this.hide()
  }

  keydown(event) {
    if (event.key === "Enter")  { event.preventDefault(); this.save() }
    if (event.key === "Escape") { this.hide() }
  }
}
