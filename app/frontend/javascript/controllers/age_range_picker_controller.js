import { Controller } from "@hotwired/stimulus"

// Drives the age-range chip editor on the person form. Mirrors the sector chip
// UI: the "Add age range" button inserts a new chip with a select (like cocoon's
// "Add Sector"), persisted chips show the name as a span, and the primary star is
// single-select — lighting one clears the others — with no leader/crown flag.
// Unlike primary_sector, chips are NOT reordered: they stay in category position
// order (the server renders them that way). New chips are cloned from a <template>
// so their markup stays defined once in the ERB partial. Each chip writes
// person[category_ids][] and, when starred, person[primary_age_category_ids][].
export default class extends Controller {
  static targets = ["addButton", "template", "chip", "chipSelect", "primaryToggle"]
  static values = { total: Number }

  connect() {
    this.refreshOptions()
    this.style()
  }

  add() {
    const chip = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.addButtonTarget.insertAdjacentElement("beforebegin", chip)
    chip.querySelector("[data-age-range-picker-target='chipSelect']")?.focus()
    this.refreshOptions()
  }

  // A new chip's range was chosen: key its primary star to that id (so starring
  // submits the right category) and re-filter the other selects.
  choose(event) {
    const select = event.target
    const chip = select.closest("[data-age-range-picker-target='chip']")
    chip.dataset.categoryId = select.value
    const toggle = chip.querySelector("[data-age-range-picker-target='primaryToggle']")
    if (toggle) toggle.value = select.value
    this.refreshOptions()
  }

  remove(event) {
    event.target.closest("[data-age-range-picker-target='chip']")?.remove()
    this.refreshOptions()
  }

  // Single-select primary: lighting one star clears the others. Chips keep their
  // position order — no reordering, unlike primary_sector.
  togglePrimary(event) {
    if (event.target.checked) {
      this.primaryToggleTargets.forEach((toggle) => {
        if (toggle !== event.target) toggle.checked = false
      })
    }
    this.style()
  }

  // Darken whichever chip is primary, matching the sector chip's starred styling.
  style() {
    this.primaryToggleTargets.forEach((toggle) => {
      const chip = toggle.closest("[data-age-range-picker-target='chip']")
      if (!chip) return
      const primary = toggle.checked
      chip.classList.toggle("bg-amber-50", primary)
      chip.classList.toggle("border-amber-300", primary)
      chip.classList.toggle("bg-white", !primary)
      chip.classList.toggle("border-gray-300", !primary)
    })
  }

  // Keep each picker from offering a range already chosen by another chip, and
  // disable the add button once every range is in use.
  refreshOptions() {
    const chosen = this.chipTargets.map((chip) => chip.dataset.categoryId).filter((id) => id)
    this.chipSelectTargets.forEach((select) => {
      Array.from(select.options).forEach((option) => {
        if (!option.value) return
        option.hidden = option.value !== select.value && chosen.includes(option.value)
      })
    })
    const exhausted = chosen.length >= this.totalValue
    this.addButtonTarget.disabled = exhausted
    this.addButtonTarget.classList.toggle("opacity-50", exhausted)
    this.addButtonTarget.classList.toggle("pointer-events-none", exhausted)
  }
}
