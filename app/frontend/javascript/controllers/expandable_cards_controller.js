import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="expandable-cards"
// Expand/collapse-all control for a group of expandable-card controllers.
// Broadcasts expandAll/collapseAll (caught via @window) so each card toggles
// itself, and keeps the button's label and chevron in sync.
//
// TODO(dedupe): the form builder added a parallel expand-all/field-options pair
// (Outlets-based) that does the same job. Consolidate to one pattern — see
// PR #1606.
export default class extends Controller {
  static targets = ["label", "icon"]
  static values = { expanded: { type: Boolean, default: true } }

  toggleAll() {
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    this.dispatch(this.expandedValue ? "expandAll" : "collapseAll")
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.expandedValue ? "Collapse all" : "Expand all"
    }
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.expandedValue)
    }
  }
}
