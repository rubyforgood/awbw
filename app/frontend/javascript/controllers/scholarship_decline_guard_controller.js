import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="scholarship-decline-guard"
//
// Warns before saving when an admin changes the award amount on a scholarship
// the recipient has DECLINED. Editing the amount re-offers the award, which
// clears the recorded decline (its date and reason) and re-funds the zeroed
// allocation — so the admin confirms before that decline data is discarded.
//
// Attach to the <form>. Only guards when the declined value is true; snapshots
// the amount input(s) on connect and compares them on submit. There are two
// amount inputs in the form (one per layout), only one of which renders, so it
// tracks all of them.
export default class extends Controller {
  static values = { declined: Boolean };
  static targets = ["amount"];

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
    if (!this.declinedValue || !this.amountChanged()) return;

    const message =
      "This recipient declined the scholarship. Changing the amount re-offers " +
      "the award and will clear their decline — the recorded date and reason — " +
      "and re-fund the allocation.\n\nAre you sure you want to save this change?";

    if (!window.confirm(message)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }

  amountChanged() {
    return this.amountTargets.some((input, i) => input.value !== this.originalAmounts[i]);
  }
}
