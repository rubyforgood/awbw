import { Controller } from "@hotwired/stimulus"

// When the form re-renders with validation errors, scroll the error flash band
// into view so the registrant immediately sees what needs fixing. Attached to
// the band itself, so it only connects when an error message is present.
export default class extends Controller {
  connect() {
    this.element.scrollIntoView({ behavior: "smooth", block: "center" })
  }
}
