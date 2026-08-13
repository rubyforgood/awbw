import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="scholarship-decline-guard"
//
// Warns before saving a change that would silently reverse a recipient's
// DECLINE on the admin edit form. Two such changes clear the decline and
// re-activate the award: editing the amount (a re-offer) and ticking the
// "Agreement signed" toggle. Either way the recorded decline (date + reason)
// is discarded, so the admin confirms first.
//
// Attach to the <form>. Only guards when the declined value is true; snapshots
// the amount input(s) on connect and compares them (plus the signed checkbox
// state) on submit. There are two amount inputs (one per layout), only one of
// which renders, so it tracks all of them.
export default class extends Controller {
  static values = { declined: Boolean };
  static targets = ["amount", "signed"];

  connect() {
    this.originalAmounts = this.amountTargets.map((input) => input.value);
    this.handleSubmit = (event) => this.guardSubmit(event);
    // Capture phase so this runs before other submit listeners (e.g. submit-once).
    this.element.addEventListener("submit", this.handleSubmit, true);
  }

  disconnect() {
    this.element.removeEventListener("submit", this.handleSubmit, true);
  }

  guardSubmit(event) {
    if (!this.declinedValue) return;
    if (!this.amountChanged() && !this.markingSigned()) return;

    const message =
      "This recipient declined the scholarship. Saving this change will clear " +
      "their decline — the recorded date and reason — and re-activate the award.\n\n" +
      "Are you sure you want to save this change?";

    if (!window.confirm(message)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }

  amountChanged() {
    return this.amountTargets.some((input, i) => input.value !== this.originalAmounts[i]);
  }

  markingSigned() {
    return this.hasSignedTarget && this.signedTarget.checked;
  }
}
