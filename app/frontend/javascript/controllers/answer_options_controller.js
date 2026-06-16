import { Controller } from "@hotwired/stimulus"

// Manages a form field's answer options. The editable option list only makes
// sense for options-based fields, so this controller watches the answer-type
// select and reveals the answer-options section when the field becomes a
// select type (radio, dropdown, or checkbox) — otherwise a field switched to
// "Single select radio" would save with no options and render nothing on the
// public form. The chevron toggle expands/collapses the option list itself.
export default class extends Controller {
  static targets = ["type", "section", "list", "icon", "required", "requiredLabel"]
  static values = { expanded: Boolean }

  // Display-only answer types (informational text, section headers) never
  // collect a response, so they can't be required — mirrors FormField's
  // NON_INPUT_ANSWER_TYPES on the server.
  nonInputTypes = ["no_user_input", "group_header"]

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

  get nonInput() {
    return this.hasTypeTarget && this.nonInputTypes.includes(this.typeTarget.value)
  }

  render() {
    const showOptions = this.selectable
    this.sectionTargets.forEach((el) => el.classList.toggle("hidden", !showOptions))
    // Dynamic-option fields render a source badge instead of the editable list.
    if (this.hasListTarget) this.listTarget.classList.toggle("hidden", !(showOptions && this.expandedValue))
    if (this.hasIconTarget) this.iconTarget.classList.toggle("rotate-90", showOptions && this.expandedValue)
    this.renderRequired()
  }

  // Display-only fields (informational text, section headers) can't be
  // required, so hide the Required box entirely — like section headers, but
  // without their heading font. Unchecking leaves the check_box helper's
  // hidden "0" field to record the field as not required.
  renderRequired() {
    if (this.hasRequiredTarget && this.nonInput) this.requiredTarget.checked = false
    if (this.hasRequiredLabelTarget) {
      this.requiredLabelTarget.classList.toggle("hidden", this.nonInput)
    }
  }
}
