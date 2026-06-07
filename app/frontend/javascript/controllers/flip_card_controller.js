import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flip-card"
// Flips a card between its front and back faces on click or keyboard activation.
// Clicks originating from links or buttons (e.g. the profile button on the back)
// are ignored so they navigate instead of flipping the card.
// Also shows a bottom fade on the bio panel while there is more to scroll.
export default class extends Controller {
  static targets = ["inner", "bio", "fade"]
  static values = { flipped: Boolean }

  connect() {
    this.updateFade()
  }

  toggle(event) {
    if (event.target.closest("a, button")) return
    this.flippedValue = !this.flippedValue
  }

  flippedValueChanged() {
    this.innerTarget.classList.toggle("[transform:rotateY(180deg)]", this.flippedValue)
    this.element.setAttribute("aria-pressed", this.flippedValue)
    this.updateFade()
  }

  updateFade() {
    if (!this.hasBioTarget || !this.hasFadeTarget) return
    const el = this.bioTarget
    const moreBelow = el.scrollHeight - el.scrollTop - el.clientHeight > 1
    this.fadeTarget.classList.toggle("opacity-0", !moreBelow)
  }
}
