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
    // Tint the whole row while open so it's clear which field you're editing.
    // Drop the gray hover while open so it doesn't override the amber when the
    // cursor is over the row you just expanded.
    const row = this.element.closest(".nested-fields")
    row?.classList.toggle("bg-amber-50", this.expandedValue)
    row?.classList.toggle("hover:bg-gray-50", !this.expandedValue)
    // Separate expanded blocks so a wall of open fields is easier to scan.
    row?.classList.toggle("my-3", this.expandedValue)
  }
}
