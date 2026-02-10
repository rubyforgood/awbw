import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="asset-picker"
export default class extends Controller {
  static targets = ["file"];

  connect() {
    this.onUploadStart = this.uploadStarted.bind(this);
    this.onUploadProgress = this.uploadProgress.bind(this);
    this.onUploadEnd = this.uploadComplete.bind(this);

    this.fileTarget.addEventListener("direct-upload:start", this.onUploadStart);
    this.fileTarget.addEventListener(
      "direct-upload:progress",
      this.onUploadProgress,
    );
    this.fileTarget.addEventListener("direct-upload:end", this.onUploadEnd);
  }

  disconnect() {
    this.fileTarget.removeEventListener(
      "direct-upload:start",
      this.onUploadStart,
    );
    this.fileTarget.removeEventListener(
      "direct-upload:progress",
      this.onUploadProgress,
    );
    this.fileTarget.removeEventListener("direct-upload:end", this.onUploadEnd);
  }

  openFileDialog() {
    this.fileTarget.click();
  }

  fileSelected() {
    if (this.fileTarget.files.length > 0) {
      const heroImage = document.getElementById("hero-image");

      heroImage?.classList.add(
        "transition-[filter,opacity]",
        "duration-[2000ms]",
        "ease-out",
        "blur-sm",
        "saturate-0",
        "opacity-60",
        "contrast-75",
      );

      this.element.requestSubmit();
    }
  }

  uploadStarted() {
    const wrapper = document.getElementById("upload-progress");
    const bar = document.getElementById("upload-progress-bar");

    if (wrapper && bar) {
      wrapper.classList.remove("hidden");
      bar.style.width = "0%";
      bar.classList.remove("opacity-0");
    }
  }

  uploadProgress(event) {
    const bar = document.getElementById("upload-progress-bar");
    if (bar) {
      bar.style.width = `${event.detail.progress}%`;
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
