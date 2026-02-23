import { Controller } from "@hotwired/stimulus";

/**
 * Shows a spinner on a tag link when clicked while the page navigates.
 * Add data-controller="tag-link-loading" and data-action="click->tag-link-loading#showSpinner"
 * to the link. Include a target for the text (data-tag-link-loading-target="text") and
 * a target for the spinner (data-tag-link-loading-target="spinner", hidden by default).
 */
export default class extends Controller {
  static targets = ["text", "spinner"];

  connect() {
    this.reset();
  }

  showSpinner() {
    if (this.hasTextTarget && this.hasSpinnerTarget) {
      this.textTarget.classList.add("invisible");
      this.spinnerTarget.classList.remove("hidden");
    }
  }

  reset() {
    if (this.hasTextTarget && this.hasSpinnerTarget) {
      this.textTarget.classList.remove("invisible");
      this.spinnerTarget.classList.add("hidden");
    }
  }
}
