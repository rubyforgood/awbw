import { Controller } from "@hotwired/stimulus"

// Reveals a free-text "please specify" input inside an "Other" option box for
// radio/checkbox form fields. When Other is selected the text input appears,
// and whatever the user types is folded into the option's submitted value as
// "Other: <text>" — so the server stores it with no extra params or changes.
// The text input has no name attribute, so it never submits on its own.
export default class extends Controller {
  static targets = ["control", "text"]

  connect() {
    this.update()
  }

  // Fires on any change within the field (a radio/checkbox toggling on or off).
  update() {
    const selected = this.controlTarget.checked
    this.textTarget.classList.toggle("hidden", !selected)
    if (selected) this.foldValue()
  }

  // Fires while the user types in the Other box — keep Other selected and sync.
  typed() {
    if (!this.controlTarget.checked) this.controlTarget.checked = true
    this.textTarget.classList.remove("hidden")
    this.foldValue()
  }

  foldValue() {
    const text = this.textTarget.value.trim()
    this.controlTarget.value = text ? `Other: ${text}` : "Other"
  }
}
