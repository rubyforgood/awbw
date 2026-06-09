import { Controller } from "@hotwired/stimulus"

// Expands or collapses every field's options panel at once. Connected to each
// row's field-options controller via outlets, so dynamically added rows are
// included automatically.
export default class extends Controller {
  static outlets = ["field-options"]
  static targets = ["btn"]

  toggleAll() {
    const allExpanded = this.fieldOptionsOutlets.length > 0 &&
      this.fieldOptionsOutlets.every(c => c.expandedValue)

    this.fieldOptionsOutlets.forEach(c => { c.expandedValue = !allExpanded })

    if (this.hasBtnTarget) {
      this.btnTarget.textContent = allExpanded ? "Expand all" : "Collapse all"
    }
  }
}
