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
// on leaving edit mode each edit textarea is synced back into the matching body
// span (paired by order) so the view reflects unsaved edits. Comments use this;
// communications omit it.
//
export default class extends Controller {
  static targets = ["view", "edit", "body", "editLabel", "viewLabel"];

  connect() {
    this.editing = false;
  }

  toggle() {
    this.editing = !this.editing;

    // Leaving edit mode: sync each edit textarea into its truncated view span.
    if (!this.editing && this.hasBodyTarget) {
      this.editTargets.forEach((edit, i) => {
        const textarea = edit.querySelector("textarea");
        const body = this.bodyTargets[i];
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
