import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="print-options"

export default class extends Controller {
  static values = {
    images: Boolean,
  };

  connect() {
    this.toggle = document.getElementById("print-images-toggle");
    if (!this.toggle) return;

    //ensure value matches icon
    this.updateIcons();

    this.toggle.addEventListener("click", this.handleToggle);
  }

  disconnect() {
    if (!this.toggle) return;
    this.toggle.removeEventListener("click", this.handleToggle);
  }

  handleToggle = (event) => {
    this.imagesValue = !this.imagesValue;
    this.updateIcons();
  };
  updateIcons() {
    const checkIcon = document.getElementById("image-check-icon");
    const xIcon = document.getElementById("image-x-icon");

    checkIcon.classList.toggle("hidden", !this.imagesValue);
    xIcon.classList.toggle("hidden", this.imagesValue);
  }
}
