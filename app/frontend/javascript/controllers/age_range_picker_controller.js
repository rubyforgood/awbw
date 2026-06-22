import { Controller } from "@hotwired/stimulus"

// Drives the age-range chip editor on the person form. Mirrors the sector chip
// UI (add/remove + a primary star) but a person can serve several primary age
// groups, so the star toggles are independent — unlike primary_sector, which is
// single-select — and there is no leader/crown flag. New chips are cloned from a
// <template> so their markup stays defined once in the ERB partial. Each chip
// writes person[category_ids][] and, when starred, person[primary_age_category_ids][].
export default class extends Controller {
  static targets = ["select", "template", "chip"]

  connect() {
    this.refreshSelect()
  }

  add(event) {
    const select = event.target
    const id = select.value
    if (!id) return
    const name = select.options[select.selectedIndex].text
    const html = this.templateTarget.innerHTML
      .replaceAll("__ID__", id)
      .replaceAll("__NAME__", name)
    select.insertAdjacentHTML("beforebegin", html)
    select.value = ""
    this.refreshSelect()
  }

  remove(event) {
    event.target.closest("[data-age-range-picker-target='chip']")?.remove()
    this.refreshSelect()
  }

  // Darken the chip while it is a primary age group, matching the sector chip's
  // starred styling.
  togglePrimary(event) {
    const chip = event.target.closest("[data-age-range-picker-target='chip']")
    if (!chip) return
    const primary = event.target.checked
    chip.classList.toggle("bg-amber-50", primary)
    chip.classList.toggle("border-amber-300", primary)
    chip.classList.toggle("bg-white", !primary)
    chip.classList.toggle("border-gray-300", !primary)
  }

  // Hide options already chosen so each age range can be added at most once.
  refreshSelect() {
    const chosen = this.chipTargets.map((chip) => chip.dataset.categoryId)
    Array.from(this.selectTarget.options).forEach((option) => {
      if (!option.value) return
      option.hidden = chosen.includes(option.value)
    })
  }
}
