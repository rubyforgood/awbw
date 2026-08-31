import { Controller } from "@hotwired/stimulus"

// A slider form field: dragging the range handle shows the picked number in a
// bubble above it, fills the track up to that point, and writes the whole number
// to a hidden input (the submitted value). The hidden input stays blank until
// the person interacts, so an untouched required slider still fails presence
// validation — a range input on its own would always post its default.
export default class extends Controller {
  static targets = ["range", "value", "bubble"]
  static values = { min: Number, max: Number }

  // Thumb width, used to nudge the bubble so it stays centered over the handle
  // as it travels the track.
  thumbWidth = 16

  connect() {
    // A prefilled/re-rendered value lives on the hidden input — mirror it onto
    // the handle and show the bubble.
    if (this.valueTarget.value !== "") {
      this.rangeTarget.value = this.valueTarget.value
      this.render()
    } else {
      this.paintTrack()
    }
  }

  update() {
    this.valueTarget.value = this.rangeTarget.value
    this.render()
  }

  render() {
    this.bubbleTarget.textContent = this.rangeTarget.value
    this.bubbleTarget.classList.remove("hidden")
    this.positionBubble()
    this.paintTrack()
  }

  get percent() {
    return (this.rangeTarget.value - this.minValue) / (this.maxValue - this.minValue)
  }

  positionBubble() {
    const offset = (0.5 - this.percent) * this.thumbWidth
    this.bubbleTarget.style.left = `calc(${this.percent * 100}% + ${offset}px)`
  }

  // Native range inputs only color the thumb, so fill the track from the left up
  // to the current value.
  paintTrack() {
    const filled = this.percent * 100
    this.rangeTarget.style.background =
      `linear-gradient(to right, var(--color-primary, #2563eb) ${filled}%, #e5e7eb ${filled}%)`
  }
}
