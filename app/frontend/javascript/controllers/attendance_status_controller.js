import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="attendance-status"
// Swaps the colored icon inside the status select as the dropdown changes. The
// select looks like an ordinary form field (not the roster's autosaving chip),
// so an "Unsaved" hint is shown until the form is saved.
export default class extends Controller {
  static targets = ["select", "icon", "dirty"]
  static values = { colors: Object, icons: Object, initial: String }

  update() {
    const status = this.selectTarget.value

    if (this.hasIconTarget) {
      const allColors = Object.values(this.colorsValue).flatMap((c) => c.split(" "))
      const allIcons = Object.values(this.iconsValue).flatMap((c) => c.split(" "))
      this.iconTarget.classList.remove(...allColors, ...allIcons)
      if (this.iconsValue[status]) this.iconTarget.classList.add(...this.iconsValue[status].split(" "))
      if (this.colorsValue[status]) this.iconTarget.classList.add(...this.colorsValue[status].split(" "))
    }

    // The status only persists on form save, so flag it as unsaved while it
    // differs from the value the page loaded with. Toggle both display classes
    // so "hidden" and "inline-flex" are never set at once (they'd fight in CSS).
    if (this.hasDirtyTarget) {
      const clean = status === this.initialValue
      this.dirtyTarget.classList.toggle("hidden", clean)
      this.dirtyTarget.classList.toggle("inline-flex", !clean)
    }
  }
}
