import { Controller } from "@hotwired/stimulus"

// Drives a chip editor with a single-select "primary" star, shared by the sector
// and age-range pickers on the person/organization form and the sector/category
// checkbox grids on the story and story idea forms. Lighting one star clears
// the others; the configurable primary/default classes highlight the starred chip.
// Chips are NOT reordered — they keep their rendered (alphabetical / position)
// order, so starring doesn't reshuffle them. Profile/recipients/dashboard views
// still lead with the primary on display. The sector chip's leader (crown) flag is
// independent and CSS-only, so it needs no JS here. An optional member checkbox
// per chip (the grid's tag checkbox) stays in step: starring checks it, and
// unchecking it clears the star.
export default class extends Controller {
  static targets = ["chip", "primary", "member"]
  static classes = ["primary", "default"]

  connect() {
    this.style()
  }

  selectPrimary(event) {
    if (event.target.checked) {
      this.primaryTargets.forEach((checkbox) => {
        if (checkbox !== event.target) checkbox.checked = false
      })
      const member = this.memberIn(this.chipFor(event.target))
      if (member) member.checked = true
    }
    this.style()
  }

  selectMember(event) {
    if (event.target.checked) return
    const primary = this.primaryIn(this.chipFor(event.target))
    if (primary) primary.checked = false
    this.style()
  }

  // Reflect each chip's primary state: highlight the starred chip, reset the rest.
  style() {
    this.primaryTargets.forEach((checkbox) => {
      const chip = this.chipFor(checkbox)
      if (!chip) return
      const primary = checkbox.checked
      this.primaryClasses.forEach((klass) => chip.classList.toggle(klass, primary))
      this.defaultClasses.forEach((klass) => chip.classList.toggle(klass, !primary))
    })
  }

  chipFor(element) {
    return this.chipTargets.find((chip) => chip.contains(element))
  }

  memberIn(chip) {
    return chip && this.memberTargets.find((member) => chip.contains(member))
  }

  primaryIn(chip) {
    return chip && this.primaryTargets.find((primary) => chip.contains(primary))
  }
}
