import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="edit-toggle"
//
// Toggles a list of records between read-only view blocks and inline edit forms
// (the comments and communications boxes on the Person / Registration /
// Scholarship edit forms). Mark each persisted record's read-only block with
// data-edit-toggle-target="view" and its edit form with
// data-edit-toggle-target="edit"; clicking the toggle flips which is shown and
// swaps the button label.
//
// Optionally mark a truncated summary span with data-edit-toggle-target="body":
// on leaving edit mode each edit textarea is synced back into the body span in
// the same cocoon row so the view reflects unsaved edits. Comments use this;
// communications omit it — and the two can be interleaved in one combined
// section, so pairing is by row (not global order).
//
export default class extends Controller {
  static targets = ["view", "edit", "body", "editLabel", "viewLabel"];

  connect() {
    this.editing = false;
  }

  toggle() {
    this.editing = !this.editing;

    // Leaving edit mode: sync each edit textarea into the truncated view span in
    // the same cocoon row. Pairing by row (not global index) keeps this correct
    // when comment rows (which have a body span) and communication rows (which
    // don't) are interleaved in one combined section.
    if (!this.editing && this.hasBodyTarget) {
      this.editTargets.forEach((edit) => {
        const row = edit.closest(".nested-fields");
        const body = row?.querySelector('[data-edit-toggle-target="body"]');
        const textarea = edit.querySelector("textarea");
        if (textarea && body) {
          const text = textarea.value;
          body.textContent = text;
          body.title = text;
        }
      });
    }

    this.viewTargets.forEach((el) => el.classList.toggle("hidden", this.editing));
    this.editTargets.forEach((el) => el.classList.toggle("hidden", !this.editing));

    if (this.hasEditLabelTarget && this.hasViewLabelTarget) {
      this.editLabelTarget.classList.toggle("hidden", this.editing);
      this.viewLabelTarget.classList.toggle("hidden", !this.editing);
    }
  }
}
