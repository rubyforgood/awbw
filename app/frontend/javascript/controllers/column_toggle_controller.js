import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="column-toggle"
// Each instance is a single slide switch that shows/hides the table columns
// whose data-column-toggle-col value matches this switch's `group` value, so a
// table can host several independent column toggles (e.g. "User confirmation",
// "CE status"). Columns live outside the switch's element, under a shared
// [data-column-toggle-root] ancestor.

export default class extends Controller {
  static targets = ["toggle", "track", "knob"]
  static values = { group: String }

  toggle() {
    const checked = this.toggleTarget.checked
    const root = this.element.closest("[data-column-toggle-root]") || document

    root.querySelectorAll(`[data-column-toggle-col="${this.groupValue}"]`).forEach((el) => {
      el.classList.toggle("hidden", !checked)
    })

    this.trackTarget.classList.toggle("bg-gray-300", !checked)
    this.trackTarget.classList.toggle("bg-blue-600", checked)
    this.knobTarget.style.transform = checked ? "translateX(16px)" : ""
  }
}
