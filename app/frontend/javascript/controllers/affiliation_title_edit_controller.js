import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="affiliation-title-edit"
//
// Toggles an affiliation-title pill between its display pill and an inline edit
// form (a text input + Save). Used on the event-registration org-link editor.
export default class extends Controller {
  static targets = ["display", "form", "input"];

  edit() {
    this.displayTarget.classList.add("hidden");
    this.formTarget.classList.remove("hidden");
    if (this.hasInputTarget) {
      this.inputTarget.focus();
      this.inputTarget.select();
    }
  }

  cancel() {
    this.formTarget.classList.add("hidden");
    this.displayTarget.classList.remove("hidden");
  }
}
