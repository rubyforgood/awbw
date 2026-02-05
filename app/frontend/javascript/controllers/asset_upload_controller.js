import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="asset-upload"
export default class extends Controller {
  static targets = ["fileInput", "form", "fakeButton"];

  triggerFileInput() {
    this.fileInputTarget.click();
  }

  handleFileChange() {
    // If a file was selected, submit the form automatically
    if (this.fileInputTarget.files.length > 0) {
      this.formTarget.requestSubmit(); // modern way to submit a form
    }
  }
}
