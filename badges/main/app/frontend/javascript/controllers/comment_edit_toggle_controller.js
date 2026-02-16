import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["editLabel", "viewLabel"];

  connect() {
    this.editing = false;
  }

  toggle() {
    this.editing = !this.editing;
    this.element
      .querySelectorAll(".comment-view")
      .forEach((el) => (el.style.display = this.editing ? "none" : ""));
    this.element
      .querySelectorAll(".comment-edit")
      .forEach((el) => (el.style.display = this.editing ? "" : "none"));

    if (this.hasEditLabelTarget && this.hasViewLabelTarget) {
      this.editLabelTarget.classList.toggle("hidden", this.editing);
      this.viewLabelTarget.classList.toggle("hidden", !this.editing);
    }
  }
}
