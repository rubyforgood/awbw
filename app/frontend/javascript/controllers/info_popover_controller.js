import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="info-popover"
//
// Click the trigger button to toggle a definition panel. Closes on an outside
// click or the Escape key. Listeners added while opening are not invoked for the
// opening click itself (DOM dispatch ignores listeners added mid-dispatch), so
// the panel stays open without a setTimeout guard.
export default class extends Controller {
  static targets = ["panel"];

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this);
    this.closeOnEscape = this.closeOnEscape.bind(this);
  }

  toggle() {
    if (this.panelTarget.classList.contains("hidden")) {
      this.open();
    } else {
      this.close();
    }
  }

  open() {
    this.panelTarget.classList.remove("hidden");
    document.addEventListener("click", this.closeOnOutsideClick);
    document.addEventListener("keydown", this.closeOnEscape);
  }

  close() {
    this.panelTarget.classList.add("hidden");
    document.removeEventListener("click", this.closeOnOutsideClick);
    document.removeEventListener("keydown", this.closeOnEscape);
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close();
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close();
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick);
    document.removeEventListener("keydown", this.closeOnEscape);
  }
}
