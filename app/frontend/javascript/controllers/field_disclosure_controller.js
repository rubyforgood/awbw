import { Controller } from "@hotwired/stimulus"

// Progressive disclosure for an optional field: a hint trigger reveals a hidden
// field group. Auto-reveals on connect when the field already holds a value
// (e.g. editing a record), so a populated field is never hidden behind the hint.
//
//   <div data-controller="field-disclosure">
//     ...the primary control...
//     <button data-field-disclosure-target="trigger"
//             data-action="field-disclosure#reveal">Enter custom title</button>
//     <div class="hidden" data-field-disclosure-target="content">
//       <input data-field-disclosure-target="field">
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["trigger", "content", "field"]

  connect() {
    if (this.hasValue) this.open(false)
  }

  reveal() {
    this.open(true)
  }

  open(focus) {
    this.contentTarget.classList.remove("hidden")
    if (this.hasTriggerTarget) this.triggerTarget.classList.add("hidden")
    if (focus && this.hasFieldTarget) this.fieldTarget.focus()
  }

  get hasValue() {
    return this.hasFieldTarget && this.fieldTarget.value.trim() !== ""
  }
}
