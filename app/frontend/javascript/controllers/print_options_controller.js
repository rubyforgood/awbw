import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="print-options"

export default class extends Controller {
  static targets = ["toggle", "checkIcon", "xIcon"];
  static values = {
    images: Boolean,
  };

  connect() {
    this.updateIcons();
  }

  handleToggle() {
    this.imagesValue = !this.imagesValue;
    this.updateIcons();
  }

  updateIcons() {
    if (!this.hasCheckIconTarget || !this.hasXIconTarget) return;

    this.checkIconTarget.classList.toggle("hidden", !this.imagesValue);
    this.xIconTarget.classList.toggle("hidden", this.imagesValue);
  }
}
