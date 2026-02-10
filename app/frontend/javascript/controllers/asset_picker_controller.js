import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="asset-picker"
export default class extends Controller {
  static targets = ["file"];
  connect() {
    this.fileTarget.addEventListener(
      "direct-upload:progress",
      this.uploadProgress.bind(this),
    );

    this.fileTarget.addEventListener(
      "direct-upload:end",
      this.uploadComplete.bind(this),
    );
  }

  disconnect() {
    this.fileTarget.removeEventListener(
      "direct-upload:progress",
      this.uploadProgress.bind(this),
    );
  }
  openFileDialog() {
    this.fileTarget.click();
  }

  fileSelected() {
    if (this.fileTarget.files.length > 0) {
      const heroImage = document.getElementById("hero-image");

      heroImage?.classList.add(
        // transitions
        "transition-[filter,opacity]",
        "duration-2000",
        "ease-out",

        // loading state
        "blur-sm",
        "saturate-0",
        "opacity-60",
        "contrast-75",
      );

      this.element.requestSubmit();
    }
  }
  uploadProgress(event) {
    const progress = event.detail.progress;
    const bar = document.getElementById("upload-progress-bar");

    if (bar) {
      bar.style.width = `${progress}%`;
    }
  }

  uploadComplete() {
    const bar = document.getElementById("upload-progress-bar");

    if (bar) {
      bar.style.width = "100%";
      bar.classList.add("opacity-0");
    }
  }
}
