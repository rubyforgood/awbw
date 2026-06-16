import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="affiliation-title-edit"
//
// Toggles an affiliation-title pill between its display pill and an inline edit
// form (a text input + Save). Used on the event-registration org-link editor.
// Uses inline display styles so it wins over the elements' Tailwind display
// utilities (e.g. inline-flex), which would otherwise override a `hidden` class.
export default class extends Controller {
  static targets = ["display", "form", "input"];

  edit() {
    this.displayTarget.style.display = "none";
    this.formTarget.style.display = "inline-flex";
    if (this.hasInputTarget) {
      this.inputTarget.focus();
      this.inputTarget.select();
    }
  }

  cancel() {
    this.formTarget.style.display = "none";
    this.displayTarget.style.display = "";
  }
}
