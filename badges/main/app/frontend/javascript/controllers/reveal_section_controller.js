import { Controller } from "@hotwired/stimulus"

// Expands a collapsible section and scrolls it into view when the page loads
// with a matching URL hash — e.g. when linked from another page so the user
// lands on the section already open rather than collapsed or scrolled past.
//
//   <div data-controller="dropdown reveal-section"
//        data-reveal-section-anchor-value="registration_form_section"
//        data-reveal-section-target="toggle"> ... the toggle button
//        data-reveal-section-target="content"> ... the collapsible body
//
// The toggle target is clicked (reusing the dropdown controller) only when the
// content is currently hidden, keeping the dropdown's open/closed state honest.
export default class extends Controller {
  static targets = ["toggle", "content"]
  static values = { anchor: String }

  connect() {
    if (window.location.hash.slice(1) !== this.anchorValue) return
    if (this.hasContentTarget && this.contentTarget.classList.contains("hidden")) {
      this.toggleTarget.click()
    }
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }
}
