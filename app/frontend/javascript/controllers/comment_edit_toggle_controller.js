import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="comment-edit-toggle"
//
// Toggles between view and edit modes for inline comment editing.
// When exiting edit mode, syncs textarea values back to the truncated display.
//
export default class extends Controller {
  static targets = ["editLabel", "viewLabel"];

  connect() {
    this.editing = false;
  }

  toggle() {
    this.editing = !this.editing;

    // When leaving edit mode, sync textarea values to view display
    if (!this.editing) {
      this.element.querySelectorAll(".nested-fields").forEach((item) => {
        const textarea = item.querySelector(".comment-edit textarea");
        const viewBody = item.querySelector(".comment-view .comment-body");
        if (textarea && viewBody) {
          const text = textarea.value;
          viewBody.textContent =
            text.length > 135 ? text.substring(0, 132) + "..." : text;
          viewBody.title = text;
        }
      });
    }

    this.element
      .querySelectorAll(".comment-view")
      .forEach((el) => (el.style.display = this.editing ? "none" : ""));
    this.element
      .querySelectorAll(".comment-edit")
      .forEach((el) => (el.style.display = this.editing ? "" : "none"));

    if (this.hasEditLabelTarget && this.hasViewLabelTarget) {
      this.editLabelTarget.style.display = this.editing ? "none" : "";
      this.viewLabelTarget.style.display = this.editing ? "" : "none";
    }
  }
}
