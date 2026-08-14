import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="exclusive-checkboxes"
// Makes a small group of checkboxes mutually exclusive — like radios, but any can
// be left unchecked. Checking one clears the others in the group (e.g. "Delete
// instead" and "Will be deactivated" are two choices for the same row).
export default class extends Controller {
  static targets = ["box"]

  select(event) {
    if (!event.target.checked) return

    this.boxTargets.forEach((box) => {
      if (box !== event.target) box.checked = false
    })
  }
}
