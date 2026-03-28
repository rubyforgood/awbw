import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleBtn"]

  toggleAll() {
    const details = this.element.querySelectorAll("details")
    const allOpen = Array.from(details).every(d => d.open)

    details.forEach(d => d.open = !allOpen)
    this.toggleBtnTarget.textContent = allOpen ? "Expand all" : "Collapse all"
  }
}
