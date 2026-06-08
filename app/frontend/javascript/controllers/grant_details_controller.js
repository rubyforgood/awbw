import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="grant-details"
// Shows the eligibility criteria + tasks for the grant currently chosen in the
// grant-select picker. Each grant's block is pre-rendered (a "detail" target keyed
// by data-grant-id) and hidden; this controller reveals the matching one in
// response to the picker's grant-select:change event.
export default class extends Controller {
  static targets = ["detail"];

  update(event) {
    this.show(event.detail.grantId);
  }

  show(grantId) {
    const id = grantId ? String(grantId) : "";
    this.detailTargets.forEach((el) => {
      el.classList.toggle("hidden", id === "" || el.dataset.grantId !== id);
    });
  }
}
