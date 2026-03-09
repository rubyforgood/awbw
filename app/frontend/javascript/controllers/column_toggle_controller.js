import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="column-toggle"
// Toggles visibility of table columns marked with a data attribute.

export default class extends Controller {
  static targets = ["toggle", "track", "knob"]

  toggle() {
    const checked = this.toggleTarget.checked
    this.element.querySelectorAll("[data-column-toggle-col]").forEach((el) => {
      el.classList.toggle("hidden", !checked)
    })

    if (this.hasTrackTarget) {
      this.trackTarget.classList.toggle("bg-gray-300", !checked)
      this.trackTarget.classList.toggle("bg-blue-600", checked)
    }
    if (this.hasKnobTarget) {
      this.knobTarget.style.transform = checked ? "translateX(16px)" : ""
    }
  }
}
