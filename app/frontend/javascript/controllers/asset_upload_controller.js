import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="asset-upload"
export default class extends Controller {
  static targets = ["fileInput", "form", "fakeButton", "uploadLabel"];

  triggerFileInput() {
    this.fileInputTarget.click();
  }

  handleFileChange() {
    // If a file was selected, submit the form automatically
    if (this.fileInputTarget.files.length > 0) {
      this.showSpinner();
      this.formTarget.requestSubmit();
    }
  }
  showSpinner() {
    if (this.hasUploadLabelTarget) {
      // Replace the label’s inner HTML with a spinner
      this.uploadLabelTarget.innerHTML = `<i class="fa-solid fa-spinner animate-spin text-gray-600 text-5xl"></i>`;
    }
  }
}
