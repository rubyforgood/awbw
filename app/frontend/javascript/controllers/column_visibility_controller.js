import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="column-visibility"
// Show/hide individual matrix columns. Place this controller on a wrapper that
// contains both the toggle menu and the table. Each menu checkbox carries
// data-column-visibility-key-param="<col>" and data-action="column-visibility#toggle";
// every matching cell/header is tagged data-onboarding-col="<col>".
export default class extends Controller {
  toggle(event) {
    const key = event.params.key
    const visible = event.target.checked
    this.element
      .querySelectorAll(`[data-onboarding-col="${key}"]`)
      .forEach((el) => el.classList.toggle("hidden", !visible))
  }
}
