import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="expandable-card"
// Collapses or expands a single card's body and rotates its chevron. Also
// responds to expand-/collapse-all events broadcast by the parent
// expandable-cards controller. With a collapsed class (e.g. line-clamp-2), the
// body stays visible and only that class is toggled; a toggle target then shows
// only while the clamp actually cuts text off.
export default class extends Controller {
  static targets = ["body", "icon", "toggle"]
  static classes = ["collapsed"]
  static values = {
    expanded: { type: Boolean, default: true },
    overflowing: { type: Boolean, default: false }
  }

  connect() {
    if (!this.hasCollapsedClass || !this.hasToggleTarget) return
    // Fires on first layout and whenever the row is resized or un-hidden (paging, filtering).
    this.observer = new ResizeObserver(() => this.measure())
    this.observer.observe(this.bodyTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  measure() {
    if (this.expandedValue || !this.bodyTarget.clientHeight) return
    this.overflowingValue = this.bodyTarget.scrollHeight > this.bodyTarget.clientHeight + 1
  }

  overflowingValueChanged() {
    if (!this.hasToggleTarget) return
    this.toggleTarget.classList.toggle("invisible", !this.overflowingValue)
    this.dispatch("measured")
  }

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
    if (!this.hasBodyTarget) return
    if (this.hasCollapsedClass) {
      this.collapsedClasses.forEach(name => this.bodyTarget.classList.toggle(name, !this.expandedValue))
    } else {
      this.bodyTarget.classList.toggle("hidden", !this.expandedValue)
    }
    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.expandedValue)
    }
    this.element.setAttribute("aria-expanded", this.expandedValue)
  }
}
