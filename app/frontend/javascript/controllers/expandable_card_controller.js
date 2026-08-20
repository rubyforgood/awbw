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

  // Match the expanded state to a checkbox's checked state (e.g. a "Published"
  // toggle that expands on check, collapses on uncheck). The chevron can still
  // override afterward.
  syncToCheckbox(event) {
    this.expandedValue = event.target.checked
  }

  // Toggle from a click anywhere on the card chrome, but ignore clicks inside the
  // expanded editor body so interacting with its fields doesn't collapse it.
  toggleFromRow(event) {
    if (this.hasBodyTarget && this.bodyTarget.contains(event.target)) return
    this.toggle()
  }

  // Let a nested control (e.g. the Published toggle) handle its own click without
  // bubbling up to the card-level toggle.
  stopPropagation(event) {
    event.stopPropagation()
  }

  expandedValueChanged() {
    this.bodyTarget.classList.toggle("hidden", !this.expandedValue)
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.expandedValue)
    }
    this.element.setAttribute("aria-expanded", this.expandedValue)
  }
}
