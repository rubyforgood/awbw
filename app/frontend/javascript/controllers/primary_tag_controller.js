import { Controller } from "@hotwired/stimulus"

// Drives a chip editor with a single-select "primary" star, shared by the sector
// and age-range pickers on the person/organization form. Lighting one star clears
// the others; the configurable primary/default classes highlight the starred chip.
// Chips are NOT reordered — they keep their rendered (alphabetical / position)
// order, so starring doesn't reshuffle them. Profile/recipients/dashboard views
// still lead with the primary on display. The sector chip's leader (crown) flag is
// independent and CSS-only, so it needs no JS here.
export default class extends Controller {
  static targets = ["chip", "primary"]
  static classes = ["primary", "default"]

  connect() {
    this.style()
  }

  selectPrimary(event) {
    if (event.target.checked) {
      this.primaryTargets.forEach((checkbox) => {
        if (checkbox !== event.target) checkbox.checked = false
      })
    }
    this.style()
  }

  // Reflect each chip's primary state: highlight the starred chip, reset the rest.
  style() {
    this.primaryTargets.forEach((checkbox) => {
      const chip = checkbox.closest("[data-primary-tag-target='chip']")
      if (!chip) return
      const primary = checkbox.checked
      this.primaryClasses.forEach((klass) => chip.classList.toggle(klass, primary))
      this.defaultClasses.forEach((klass) => chip.classList.toggle(klass, !primary))
    })
  }
}
