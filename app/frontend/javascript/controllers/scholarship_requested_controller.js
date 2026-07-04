import { Controller } from "@hotwired/stimulus"

// Colors the "Requested" toggle and its whole card to signal save state: amber
// while the choice is pending (changed but not yet saved with the registration
// form), the scholarship theme color once it matches the stored "on" value, and
// neutral gray when stored as off. Mounted on the <section> so this.element is
// the card to tint. When a scholarship has already been awarded the toggle is
// gone — there's no checkbox to read, so we leave the server-rendered tint.
export default class extends Controller {
  static targets = ["checkbox", "track"]
  static values = { initial: Boolean }

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.hasCheckboxTarget) return

    const checked = this.checkboxTarget.checked
    const pending = checked !== this.initialValue

    this.trackTarget.classList.toggle("bg-amber-500", pending)
    this.trackTarget.classList.toggle("bg-fuchsia-600", checked && !pending)
    this.trackTarget.classList.toggle("bg-gray-200", !checked && !pending)

    this.element.classList.toggle("bg-amber-50", pending)
    this.element.classList.toggle("border-amber-200", pending)
    this.element.classList.toggle("bg-fuchsia-50", checked && !pending)
    this.element.classList.toggle("border-fuchsia-200", checked && !pending)
    this.element.classList.toggle("bg-white", !checked && !pending)
    this.element.classList.toggle("border-gray-200", !checked && !pending)
  }
}
