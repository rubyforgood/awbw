import { Controller } from "@hotwired/stimulus"

// Keeps at most one checkbox in a group checked (radio-like), while still
// allowing every option to be unchecked. Used for the single "Primary" age
// range toggle on the person/organization edit forms — picking a new primary
// clears the previous one, mirroring the single primary sector.
export default class extends Controller {
  static targets = ["option"]

  connect() {
    this.enforce()
  }

  select(event) {
    if (!event.target.checked) return
    this.optionTargets.forEach((checkbox) => {
      if (checkbox !== event.target) checkbox.checked = false
    })
  }

  // On load, keep only the first checked option set (defensive against legacy
  // data that marked several primaries before the single-primary rule).
  enforce() {
    this.optionTargets.filter((checkbox) => checkbox.checked).slice(1).forEach((checkbox) => {
      checkbox.checked = false
    })
  }
}
