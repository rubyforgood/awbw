import { Controller } from "@hotwired/stimulus"

// Manages a form field's answer options. The editable option list only makes
// sense for options-based fields, so this controller watches the answer-type
// select and reveals the answer-options section when the field becomes a
// select type (radio, dropdown, or checkbox) — otherwise a field switched to
// "Single select radio" would save with no options and render nothing on the
// public form. The chevron toggle expands/collapses the option list itself.
export default class extends Controller {
  static targets = ["type", "section", "list", "icon"]
  static values = { expanded: Boolean }

  connect() {
    this.render()
  }

  typeChanged() {
    this.render()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    this.render()
  }

  // Selectable answer types (radio, dropdown, checkbox) all carry "select"
  // in their value; free-form and header types do not.
  get selectable() {
    return this.hasTypeTarget && this.typeTarget.value.includes("select")
  }

  render() {
    const showOptions = this.selectable
    this.sectionTargets.forEach((el) => el.classList.toggle("hidden", !showOptions))
    // Dynamic-option fields render a source badge instead of the editable list.
    if (this.hasListTarget) this.listTarget.classList.toggle("hidden", !(showOptions && this.expandedValue))
    if (this.hasIconTarget) this.iconTarget.classList.toggle("rotate-90", showOptions && this.expandedValue)
  }
}
