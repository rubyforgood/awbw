import { Controller } from "@hotwired/stimulus"

// Mounted on a native <details>; a child Cancel button closes it back to the
// summary via data-action="disclosure#close".
export default class extends Controller {
  close() {
    this.element.open = false
  }
}
