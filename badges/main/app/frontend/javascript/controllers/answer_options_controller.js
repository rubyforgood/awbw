import { Controller } from "@hotwired/stimulus"

// Toggles the editable list of a multiple-choice field's answer options,
// nested inside the expanded field-options panel.
export default class extends Controller {
  static targets = ["panel", "icon"]
  static values = { expanded: Boolean }

  toggle() {
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    this.panelTarget.classList.toggle("hidden", !this.expandedValue)
    this.iconTarget.classList.toggle("rotate-90", this.expandedValue)
  }
}
