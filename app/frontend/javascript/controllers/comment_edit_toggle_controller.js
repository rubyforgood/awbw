import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="comment-edit-toggle"
//
// Toggles between view and edit modes for inline comment editing.
// When exiting edit mode, syncs textarea values back to the truncated display.
//
export default class extends Controller {
  static targets = ["editLabel", "viewLabel", "commentView", "commentEdit"];
  static values = { editing: Boolean };

  toggle() {
    this.editingValue = !this.editingValue;

    // When leaving edit mode, sync textarea values to view display
    if (!this.editingValue) {
      this.commentEditTargets.forEach((editDiv, i) => {
        const textarea = editDiv.querySelector("textarea");
        const viewBody = this.commentViewTargets[i]?.querySelector(".comment-body");
        if (textarea && viewBody) {
          const text = textarea.value;
          viewBody.textContent =
            text.length > 135 ? text.substring(0, 132) + "..." : text;
          viewBody.title = text;
        }
      });
    }

    this.commentViewTargets.forEach((el) => el.classList.toggle("hidden", this.editingValue));
    this.commentEditTargets.forEach((el) => el.classList.toggle("hidden", !this.editingValue));

    if (this.hasEditLabelTarget && this.hasViewLabelTarget) {
      this.editLabelTarget.classList.toggle("hidden", this.editingValue);
      this.viewLabelTarget.classList.toggle("hidden", !this.editingValue);
    }
  }
}
