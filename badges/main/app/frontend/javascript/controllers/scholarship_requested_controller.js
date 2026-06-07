import { Controller } from "@hotwired/stimulus"

// Colors the "Requested" toggle to signal save state: amber while the choice is
// pending (changed but not yet saved with the registration form), the
// scholarship theme color once it matches the stored "on" value, and neutral
// gray when stored as off.
export default class extends Controller {
  static targets = ["checkbox", "track"]
  static values = { initial: Boolean }

  connect() {
    this.refresh()
  }

  refresh() {
    const checked = this.checkboxTarget.checked
    const pending = checked !== this.initialValue

    this.trackTarget.classList.toggle("bg-amber-500", pending)
    this.trackTarget.classList.toggle("bg-fuchsia-600", checked && !pending)
    this.trackTarget.classList.toggle("bg-gray-200", !checked && !pending)
  }
}
