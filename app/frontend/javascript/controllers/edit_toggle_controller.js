import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="edit-toggle"
//
// Toggles a list of records between read-only view blocks and inline edit forms
// (used by the comments and communications boxes on the Person / Registration /
// Scholarship edit forms). Each persisted record renders a `.{view}` block and a
// hidden `.{edit}` block; clicking the toggle flips which is shown and swaps the
// button label.
//
// Configure the block classes per caller:
//   data-edit-toggle-view-class-value="comment-view"
//   data-edit-toggle-edit-class-value="comment-edit"
//   data-edit-toggle-body-class-value="comment-body"  (optional)
//
// When a body class is given, leaving edit mode syncs each edit textarea back
// into the matching truncated `.{body}` span so the view reflects unsaved edits.
//
export default class extends Controller {
  static targets = ["editLabel", "viewLabel"];
  static values = {
    viewClass: { type: String, default: "editable-view" },
    editClass: { type: String, default: "editable-edit" },
    bodyClass: { type: String, default: "" },
    truncate: { type: Number, default: 135 }
  };

  connect() {
    this.editing = false;
  }

  toggle() {
    this.editing = !this.editing;

    // When leaving edit mode, sync edit textareas into their truncated view.
    if (!this.editing && this.bodyClassValue) {
      this.element.querySelectorAll(".nested-fields").forEach((item) => {
        const textarea = item.querySelector(`.${this.editClassValue} textarea`);
        const viewBody = item.querySelector(
          `.${this.viewClassValue} .${this.bodyClassValue}`
        );
        if (textarea && viewBody) {
          const text = textarea.value;
          const max = this.truncateValue;
          viewBody.textContent =
            text.length > max ? text.substring(0, max - 3) + "..." : text;
          viewBody.title = text;
        }
      });
    }

    this.element
      .querySelectorAll(`.${this.viewClassValue}`)
      .forEach((el) => (el.style.display = this.editing ? "none" : ""));
    this.element
      .querySelectorAll(`.${this.editClassValue}`)
      .forEach((el) => (el.style.display = this.editing ? "" : "none"));

    if (this.hasEditLabelTarget && this.hasViewLabelTarget) {
      this.editLabelTarget.style.display = this.editing ? "none" : "";
      this.viewLabelTarget.style.display = this.editing ? "" : "none";
    }
  }
}
