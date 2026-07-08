import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="field-required"
//
// Makes the marked required field(s) required only once the row is in use (any
// participating `field` target has content). An untouched, cocoon-added row
// stays optional so the parent form can still submit — reject_if drops empty
// rows server-side — while an engaged row can't be saved without its required
// field, so a partially-filled entry is never silently dropped.
//
// Mark every participating input with data-field-required-target="field" and the
// input(s) that must be filled with data-field-required-target="required" (an
// input can be both, e.g. a required field that also triggers the check).
//
export default class extends Controller {
  static targets = ["field", "required"];

  connect() {
    this.update();
  }

  update() {
    const inUse = this.fieldTargets.some((el) => el.value.trim() !== "");
    this.requiredTargets.forEach((el) => (el.required = inUse));
  }
}
