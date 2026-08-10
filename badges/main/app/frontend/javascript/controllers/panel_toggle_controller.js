import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="panel-toggle"
// Independent show/hide toggles: each button controls the panel at the same
// index (DOM order) in panelTargets, swapping its own label and aria-expanded.
// Revealing a hidden panel that holds a lazy Turbo frame lets the frame load on
// first show, so charts stay off the initial request until the admin asks.
export default class extends Controller {
  static targets = ["button", "panel", "label"]

  toggle(event) {
    const button = event.currentTarget
    const index = this.buttonTargets.indexOf(button)
    const panel = this.panelTargets[index]
    if (!panel) return

    const hidden = panel.classList.toggle("hidden")
    button.setAttribute("aria-expanded", String(!hidden))

    const label = this.labelTargets[index]
    if (label) {
      label.textContent = hidden
        ? button.dataset.panelToggleHiddenLabel
        : button.dataset.panelToggleShownLabel
    }
  }
}
