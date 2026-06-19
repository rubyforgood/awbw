import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="icon-select"
// Swaps the colored icon inside a select as the dropdown changes, driven by
// colors/icons maps keyed on the option value. Used by the registration-status
// and payment-method selects. The select looks like an ordinary form field (not
// the roster's autosaving chip), so an "Unsaved" hint is shown until saved.
export default class extends Controller {
  static targets = ["select", "icon", "dirty"]
  static values = { colors: Object, icons: Object, initial: String }

  update() {
    const value = this.selectTarget.value

    if (this.hasIconTarget) {
      const allColors = Object.values(this.colorsValue).flatMap((c) => c.split(" "))
      const allIcons = Object.values(this.iconsValue).flatMap((c) => c.split(" "))
      this.iconTarget.classList.remove(...allColors, ...allIcons)
      if (this.iconsValue[value]) this.iconTarget.classList.add(...this.iconsValue[value].split(" "))
      if (this.colorsValue[value]) this.iconTarget.classList.add(...this.colorsValue[value].split(" "))
    }

    // The value only persists on form save, so flag it as unsaved while it
    // differs from the value the page loaded with. Toggle both display classes
    // so "hidden" and "inline-flex" are never set at once (they'd fight in CSS).
    if (this.hasDirtyTarget) {
      const clean = value === this.initialValue
      this.dirtyTarget.classList.toggle("hidden", clean)
      this.dirtyTarget.classList.toggle("inline-flex", !clean)
    }
  }
}
