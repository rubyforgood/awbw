import { Controller } from "@hotwired/stimulus"

// Reveals a free-text "please specify" input inside selectable options that ask
// for more detail (e.g. "Other", "Word of Mouth"). When such an option is
// selected its text input appears, and whatever the user types is folded into
// the option's submitted value as "<option>: <text>" — so the server stores it
// with no extra params or changes. A field may offer several such options; the
// nth control is paired with the nth text input by their order in the DOM. The
// text inputs have no name attribute, so they never submit on their own.
export default class extends Controller {
  static targets = ["control", "text"]

  connect() {
    // Capture each control's base value (its option label) before folding
    // rewrites it, so we can rebuild "<option>: <text>" on every change.
    this.controlTargets.forEach((control) => {
      control.dataset.specifyBase = control.value
    })
    this.update()
  }

  // Fires on any change within the field — reveal each selected option's text
  // input (folding its value), hide the rest.
  update() {
    this.controlTargets.forEach((control, i) => {
      const text = this.textTargets[i]
      text.classList.toggle("hidden", !control.checked)
      if (control.checked) this.foldValue(control, text)
    })
  }

  // Fires while typing in a specify box — keep its control selected and sync.
  typed(event) {
    const text = event.target
    const control = this.controlTargets[this.textTargets.indexOf(text)]
    if (!control.checked) control.checked = true
    text.classList.remove("hidden")
    this.foldValue(control, text)
  }

  foldValue(control, text) {
    const base = control.dataset.specifyBase
    const typed = text.value.trim()
    control.value = typed ? `${base}: ${typed}` : base
  }
}
