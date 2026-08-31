import { Controller } from "@hotwired/stimulus"

// Keeps a slider form field's range handle and its number box in step: dragging
// the handle fills the number box, typing a number moves the handle (clamped to
// the field's bounds), and the range track fills up to the current value. The
// number input carries the submitted value; the range is display/entry only.
export default class extends Controller {
  static targets = ["range", "number"]
  static values = { min: Number, max: Number }

  connect() {
    // A prefilled/re-rendered value lives on the number box — mirror it onto the
    // handle. An untouched field leaves the number box blank so "required" still
    // catches a non-answer.
    if (this.numberTarget.value !== "") this.rangeTarget.value = this.numberTarget.value
    this.paint()
  }

  rangeChanged() {
    this.numberTarget.value = this.rangeTarget.value
    this.paint()
  }

  numberChanged() {
    if (this.numberTarget.value === "") {
      this.rangeTarget.value = this.minValue
      this.paint()
      return
    }
    const clamped = Math.min(Math.max(Number(this.numberTarget.value), this.minValue), this.maxValue)
    this.numberTarget.value = clamped
    this.rangeTarget.value = clamped
    this.paint()
  }

  // Fills the track from the left up to the handle, since native range inputs
  // only color the thumb.
  paint() {
    const percent = ((this.rangeTarget.value - this.minValue) / (this.maxValue - this.minValue)) * 100
    this.rangeTarget.style.background =
      `linear-gradient(to right, var(--color-primary, #2563eb) ${percent}%, #e5e7eb ${percent}%)`
  }
}
