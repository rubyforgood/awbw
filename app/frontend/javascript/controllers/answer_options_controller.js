import { Controller } from "@hotwired/stimulus"

// Manages a form field's answer options. The editable option list only makes
// sense for multiple-choice fields, so this controller watches the answer-type
// select and reveals the answer-options section when the field becomes a
// single/multiple choice type — otherwise a field switched to "Single choice
// radio" would save with no options and render nothing on the public form.
// The chevron toggle expands/collapses the option list itself.
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

  get multipleChoice() {
    return this.hasTypeTarget && this.typeTarget.value.includes("multiple_choice")
  }

  render() {
    const isMultipleChoice = this.multipleChoice
    this.sectionTargets.forEach((el) => el.classList.toggle("hidden", !isMultipleChoice))
    // Dynamic-option fields render a source badge instead of the editable list.
    if (this.hasListTarget) this.listTarget.classList.toggle("hidden", !(isMultipleChoice && this.expandedValue))
    if (this.hasIconTarget) this.iconTarget.classList.toggle("rotate-90", isMultipleChoice && this.expandedValue)
  }
}
