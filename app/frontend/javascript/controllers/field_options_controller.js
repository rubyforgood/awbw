import { Controller } from "@hotwired/stimulus"

// Collapses a form field's secondary settings (width, min words, one-time)
// behind a chevron. The main row stays visible; the panel toggles open.
export default class extends Controller {
  static targets = ["panel", "icon"]
  static values = { expanded: Boolean }

  toggle() {
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    this.panelTarget.classList.toggle("hidden", !this.expandedValue)
    this.iconTarget.classList.toggle("rotate-180", this.expandedValue)
  }
}
