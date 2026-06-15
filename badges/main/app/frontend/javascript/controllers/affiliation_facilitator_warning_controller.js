import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="affiliation-facilitator-warning"
//
// Warns before saving when a facilitator affiliation (one with "facilitator"
// in its title) is added, removed, or edited. Those affiliations — together
// with their start and end dates — determine the organization's status with
// AWBW, which is calculated dynamically, so the user is asked to confirm
// the change before the form submits.
//
// Attach to the <form> element. Snapshots the affiliation rows on connect and
// compares them against the current state on submit; if a facilitator-relevant
// change is detected the user must confirm or the submission is cancelled.
export default class extends Controller {
  connect() {
    this.snapshots = this.captureSnapshots();
    this.handleSubmit = (event) => this.guardSubmit(event);
    // Capture phase so this runs before other submit listeners (e.g. dirty-form).
    this.element.addEventListener("submit", this.handleSubmit, true);
  }

  disconnect() {
    this.element.removeEventListener("submit", this.handleSubmit, true);
  }

  guardSubmit(event) {
    if (!this.facilitatorChangePresent()) return;

    const message =
      "You're adding, removing, or editing a facilitator affiliation. " +
      "This affects the organization's status with AWBW, which is calculated " +
      "from facilitator affiliations and their start and end dates.\n\n" +
      "Are you sure you want to save this change?";

    if (!window.confirm(message)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }

  rows() {
    return Array.from(this.element.querySelectorAll(".nested-fields"));
  }

  keyFor(row) {
    const field = row.querySelector("[name*='affiliations_attributes']");
    const match = field?.name.match(/\[affiliations_attributes\]\[([^\]]+)\]/);
    return match ? match[1] : null;
  }

  stateFor(row) {
    const title = row.querySelector("[name*='[title]']")?.value || "";
    const startDate = row.querySelector("[name*='[start_date]']")?.value || "";
    const endDate = row.querySelector("[name*='[end_date]']")?.value || "";
    const destroyInput = row.querySelector("input[name*='_destroy']");
    const destroyed =
      (destroyInput && destroyInput.value === "1") ||
      row.style.display === "none";

    return {
      title,
      startDate,
      endDate,
      destroyed,
      facilitator: title.toLowerCase().includes("facilitator"),
    };
  }

  captureSnapshots() {
    const snapshots = {};
    this.rows().forEach((row) => {
      const key = this.keyFor(row);
      if (key) snapshots[key] = this.stateFor(row);
    });
    return snapshots;
  }

  facilitatorChangePresent() {
    return this.rows().some((row) => {
      const key = this.keyFor(row);
      const current = this.stateFor(row);
      const previous = key ? this.snapshots[key] : null;

      // New row added in this session — relevant if it's a non-removed facilitator.
      if (!previous) return current.facilitator && !current.destroyed;

      // Removal — relevant only if the row was a facilitator before.
      if (current.destroyed) return previous.facilitator && !previous.destroyed;

      // Edit — relevant if the row is (or was) a facilitator and any field changed.
      const involvesFacilitator = previous.facilitator || current.facilitator;
      const changed =
        current.title !== previous.title ||
        current.startDate !== previous.startDate ||
        current.endDate !== previous.endDate;

      return involvesFacilitator && changed;
    });
  }
}
