import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="expandable-card"
// Collapses or expands a single card's body and rotates its chevron. Also
// responds to expand-/collapse-all events broadcast by the parent
// expandable-cards controller.
export default class extends Controller {
  static targets = ["body", "icon"]
  static values = { expanded: { type: Boolean, default: true } }

  toggle() {
    this.expandedValue = !this.expandedValue
  }

  expand() {
    this.expandedValue = true
  }

  collapse() {
    this.expandedValue = false
  }

  expandedValueChanged() {
    this.bodyTarget.classList.toggle("hidden", !this.expandedValue)
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.expandedValue)
    }
    this.element.setAttribute("aria-expanded", this.expandedValue)
  }
}
