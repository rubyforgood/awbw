import { Controller } from "@hotwired/stimulus"

// Drives the CE "Requested" toggle on the registration form, mirroring the
// scholarship toggle. Colors the track to signal save state — amber while the
// choice is pending (changed but not yet saved), the continuing-education theme
// color (teal) once it matches the stored "on" value, neutral gray when off —
// and highlights the whole card with a teal ring while it's on.
export default class extends Controller {
  static targets = ["checkbox", "track", "box"]
  static values = { initial: Boolean }

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.hasCheckboxTarget) return

    const checked = this.checkboxTarget.checked
    const pending = checked !== this.initialValue

    this.trackTarget.classList.toggle("bg-amber-500", pending)
    this.trackTarget.classList.toggle("bg-teal-600", checked && !pending)
    this.trackTarget.classList.toggle("bg-gray-200", !checked && !pending)

    if (this.hasBoxTarget) {
      this.boxTarget.classList.toggle("ring-2", checked)
      this.boxTarget.classList.toggle("ring-teal-400", checked)
    }
  }
}
