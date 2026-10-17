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
// unchecking it clears the star. A newly picked chip is starred when none of the
// others is, and a lone remaining chip is starred, matching the server's rule
// that a sole tag is the primary one.
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
    this.promoteSole()
  }

  selectMember(event) {
    const primary = this.primaryIn(this.chipFor(event.target))
    if (event.target.checked) {
      this.promotePicked(primary)
      return
    }
    if (primary) primary.checked = false
    this.promoteSole()
  }

  // cocoon:after-insert — the inserted chip is the new pick.
  promoteInserted(event) {
    this.promotePicked(this.primaryIn(event.detail.item))
  }

  promotePicked(primary) {
    if (primary && !this.selectedPrimaries().some((other) => other.checked)) primary.checked = true
    this.style()
  }

  promoteSole() {
    const selected = this.selectedPrimaries()
    if (selected.length === 1) selected[0].checked = true
    this.style()
  }

  selectedPrimaries() {
    return this.primaryTargets.filter((primary) => this.isSelected(this.chipFor(primary)))
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

  // A grid chip counts when its tag is checked; a cocoon chip until it's removed (hidden).
  isSelected(chip) {
    if (!chip) return false
    const member = this.memberIn(chip)
    return member ? member.checked : chip.style.display !== "none"
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
