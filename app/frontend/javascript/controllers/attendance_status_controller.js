import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="attendance-status"
// Swaps the colored icon inside the status select as the dropdown changes. The
// select looks like an ordinary form field (not the roster's autosaving chip),
// so an "Unsaved" hint is shown until the form is saved.
//
// The per-day attendance checkboxes drive the status the same way the Onboarding
// matrix does: toggling a day rolls the status forward/back (registered →
// incomplete_attendance → attended), but only while the status is an active one —
// deliberate manual states (cancelled, no_show, transferred_out) are never
// overridden. Mirrors EventRegistration#sync_attendance_status_to_days!.
export default class extends Controller {
  static targets = ["select", "icon", "dirty", "day"]
  static values = { colors: Object, icons: Object, initial: String, activeStatuses: Array, dayCount: Number }

  // Recompute the status from how many day checkboxes are checked, then reflect it
  // in the dropdown (which re-renders the icon and the unsaved hint via update()).
  deriveFromDays() {
    if (!this.activeStatusesValue.includes(this.selectTarget.value)) return

    const checked = this.dayTargets.filter((day) => day.checked).length
    let derived = "incomplete_attendance"
    if (checked === 0) derived = "registered"
    else if (checked >= this.dayCountValue) derived = "attended"

    if (this.selectTarget.value === derived) return
    this.selectTarget.value = derived
    this.update()
  }

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
