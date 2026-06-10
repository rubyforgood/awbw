import { Controller } from "@hotwired/stimulus"

// Shows inline feedback as a subsection checkbox is toggled on the
// edit-subsections form: a destructive warning when an existing subsection is
// unchecked, and an additive note when a new subsection is checked. Stays
// silent when the checkbox matches the subsection's saved state.
export default class extends Controller {
  static targets = ["checkbox", "message"]
  static values = { included: Boolean }

  update() {
    const checked = this.checkboxTarget.checked

    if (checked === this.includedValue) {
      this.clear()
      return
    }

    if (checked) {
      this.show("This subsection and default questions will be added in order.", false)
    } else {
      this.show("Unchecking a subsection permanently removes it and all of its questions.", true)
    }
  }

  show(text, destructive) {
    this.messageTarget.textContent = text
    this.messageTarget.classList.remove("hidden", "text-red-600", "text-green-700")
    this.messageTarget.classList.add(destructive ? "text-red-600" : "text-green-700")
  }

  clear() {
    this.messageTarget.textContent = ""
    this.messageTarget.classList.add("hidden")
  }
}
