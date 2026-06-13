import { Controller } from "@hotwired/stimulus"

// Drives the sector chip editor on the person/organization form. Enforces a
// single primary sector — lighting one star clears the others — and darkens
// the starred chip. The leader (crown) flag is independent and multi-select,
// so it needs no JS and is styled purely via CSS (peer-checked).
export default class extends Controller {
  static targets = ["chip", "primary"]

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

  // Reflect each chip's primary state: darker fill and stronger border when set.
  style() {
    this.primaryTargets.forEach((checkbox) => {
      const chip = checkbox.closest("[data-sector-chips-target='chip']")
      if (!chip) return
      const primary = checkbox.checked
      chip.classList.toggle("bg-lime-200", primary)
      chip.classList.toggle("border-lime-500", primary)
      chip.classList.toggle("bg-white", !primary)
      chip.classList.toggle("border-gray-300", !primary)
    })
  }
}
