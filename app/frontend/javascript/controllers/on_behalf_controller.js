import { Controller } from "@hotwired/stimulus"

// An admin can fill out a public form (registration, bulk payment) on a
// not-logged-in person's behalf. The form hides identity fields (name, email,
// ...) that are already on file for the logged-in admin — but the person being
// served isn't logged in, so those fields must reappear. Reveals them when the
// "on behalf" checkbox is checked, hides them again when it's unchecked.
export default class extends Controller {
  static targets = ["toggle", "field"]

  connect() {
    this.reveal()
  }

  reveal() {
    const show = this.toggleTarget.checked
    this.fieldTargets.forEach((field) => field.classList.toggle("hidden", !show))
  }
}
