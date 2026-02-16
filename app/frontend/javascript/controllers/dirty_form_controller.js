import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dirty-form"
//
// Tracks whether a form has unsaved changes and prompts on cancel.
// Listens for input changes and cocoon nested field additions/removals.
//
// data-dirty-form-target="cancel" on the cancel link
//
export default class extends Controller {
  static targets = ["cancel"];

  connect() {
    this.dirty = false;
    this.handleChange = () => (this.dirty = true);

    this.element.addEventListener("input", this.handleChange);
    this.element.addEventListener("change", this.handleChange);
    this.element.addEventListener("cocoon:after-insert", this.handleChange);
    this.element.addEventListener("cocoon:after-remove", this.handleChange);
  }

  confirmCancel(event) {
    if (this.dirty) {
      if (!confirm("You have unsaved changes. Are you sure you want to leave?")) {
        event.preventDefault();
      }
    }
  }

  disconnect() {
    this.element.removeEventListener("input", this.handleChange);
    this.element.removeEventListener("change", this.handleChange);
    this.element.removeEventListener("cocoon:after-insert", this.handleChange);
    this.element.removeEventListener("cocoon:after-remove", this.handleChange);
  }
}
