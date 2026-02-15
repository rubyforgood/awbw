import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="workshop-toggle"
// Handles toggling between workshop dropdown and external title field
export default class extends Controller {
  static targets = ["dropdown", "externalField"];

  connect() {
    this.checkInitialState();
  }

  checkInitialState() {
    const select = this.dropdownTarget.querySelector("select");
    if (select && select.value === "new") {
      this.showExternalField();
    }
  }

  handleChange(event) {
    const value = event.target.value;
    if (value === "new") {
      this.showExternalField();
    }
  }

  showExternalField() {
    this.dropdownTarget.classList.add("hidden");
    this.externalFieldTarget.classList.remove("hidden");
  }

  showDropdown() {
    this.externalFieldTarget.classList.add("hidden");
    this.dropdownTarget.classList.remove("hidden");

    // Clear the selection back to prompt
    const select = this.dropdownTarget.querySelector("select");
    if (select) {
      select.value = "";
    }

    // Clear the external workshop title field
    const externalField = this.externalFieldTarget.querySelector("input, textarea");
    if (externalField) {
      externalField.value = "";
    }
  }
}
