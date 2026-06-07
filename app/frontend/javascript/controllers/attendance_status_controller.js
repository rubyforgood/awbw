import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="attendance-status"
// Mirrors the chosen status into the visible pill (label, color, icon) as the
// dropdown changes — styled like the roster badge, but saved with the form
// rather than autosubmitted.
export default class extends Controller {
  static targets = ["select", "label", "icon", "pill", "dirty"]
  static values = { styles: Object, icons: Object, initial: String }

  update() {
    const status = this.selectTarget.value
    const option = this.selectTarget.selectedOptions[0]
    if (option && this.hasLabelTarget) this.labelTarget.textContent = option.textContent

    if (this.hasPillTarget) {
      const allStyles = Object.values(this.stylesValue).flatMap((c) => c.split(" "))
      this.pillTarget.classList.remove(...allStyles)
      if (this.stylesValue[status]) this.pillTarget.classList.add(...this.stylesValue[status].split(" "))
    }

    if (this.hasIconTarget) {
      this.iconTarget.classList.remove(...Object.values(this.iconsValue))
      if (this.iconsValue[status]) this.iconTarget.classList.add(this.iconsValue[status])
    }

    // The status only persists on form save, so flag it as unsaved while it
    // differs from the value the page loaded with.
    if (this.hasDirtyTarget) {
      this.dirtyTarget.classList.toggle("hidden", status === this.initialValue)
    }
  }
}
