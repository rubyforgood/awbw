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
// unchecking it clears the star. A newly picked chip is starred by default when
// none of the selected chips is, and unchecking or removing the starred chip
// passes the star to the first remaining one. A star cleared by hand stays clear.
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
    const chip = this.chipFor(event.target)
    if (event.target.checked) {
      this.promotePicked(this.primaryIn(chip))
      return
    }
    this.passStarFrom(chip)
  }

  // cocoon:after-insert — the inserted chip is the new pick.
  promoteInserted(event) {
    this.promotePicked(this.primaryIn(event.detail.item))
  }

  // cocoon:before-remove, while the chip is still in the DOM.
  promoteOnRemove(event) {
    this.passStarFrom(event.detail.item)
  }

  passStarFrom(chip) {
    const primary = this.primaryIn(chip)
    if (primary?.checked) {
      primary.checked = false
      const next = this.primaryTargets.find((other) => other !== primary && this.isSelected(this.chipFor(other)))
      if (next) next.checked = true
    }
    this.style()
  }

  promotePicked(primary) {
    const starred = this.primaryTargets.some((other) => other.checked && this.isSelected(this.chipFor(other)))
    if (primary && !starred) primary.checked = true
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
