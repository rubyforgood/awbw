import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scholarship-status-toggle"
// Shows or hides every recipient's scholarship status (awarded amount + whether
// the tasks are completed) across all recipient cards at once, keeping the
// switch's label, track, knob, and aria-checked state in sync.
export default class extends Controller {
  static targets = ["status", "label", "switch", "track", "knob"]
  static values = { shown: { type: Boolean, default: false } }

  toggle() {
    this.shownValue = !this.shownValue
  }

  shownValueChanged() {
    this.statusTargets.forEach((el) => el.classList.toggle("hidden", !this.shownValue))
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.shownValue ? "Hide scholarship status" : "Show scholarship status"
    }
    if (this.hasSwitchTarget) {
      this.switchTarget.setAttribute("aria-checked", this.shownValue)
    }
    if (this.hasTrackTarget) {
      this.trackTarget.classList.toggle("bg-gray-300", !this.shownValue)
      this.trackTarget.classList.toggle("bg-fuchsia-600", this.shownValue)
    }
    if (this.hasKnobTarget) {
      this.knobTarget.classList.toggle("translate-x-[1.125rem]", this.shownValue)
      this.knobTarget.classList.toggle("translate-x-0.5", !this.shownValue)
    }
  }
}
