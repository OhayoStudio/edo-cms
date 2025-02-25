import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["menu"];

  connect() {
    document.addEventListener("click", this.handleClickOutside.bind(this));
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden");
  }

  navigate(event) {
    event.preventDefault();
    window.location.href = event.currentTarget.href;
  }


  disconnect() {
    document.removeEventListener("click", this.handleClickOutside.bind(this));
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden");
    }
  }
}
