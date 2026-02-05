import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="asset-upload"
export default class extends Controller {
  static targets = [
    "fileInput",
    "fileName",
    "form",
    "fakeButton",
    "uploadLabel",
    "typeSelect",
  ];

  selectedType = "GalleryAsset";
  formTargetConnected(element) {
    console.log("Form target connected:", element);
    this.updateFilenameWithPreview();
  }
  triggerFileInput({ params: { type } }) {
    this.selectedType = type;
    this.fileInputTarget.click();
  }
  handleFileChange() {
    if (this.fileInputTarget.files.length === 0) return;

    if (this.hasTypeSelectTarget && this.selectedType) {
      this.typeSelectTarget.value = this.selectedType;
    }

    this.showSpinner();
    this.formTarget.requestSubmit();

    // reset if needed
    this.selectedType = "GalleryAsset";
  }

  showSpinner() {
    if (this.hasUploadLabelTarget) {
      this.uploadLabelTarget.innerHTML = `<i class="fa-solid fa-spinner animate-spin text-gray-600 text-5xl"></i>`;
    }
  }
  updateFilenameWithPreview() {
    if (!this.hasFileNameTarget) return;

    const primaryAsset = document.querySelector("[id^='primary_asset_']");
    if (!primaryAsset) return;

    const img = primaryAsset.querySelector("img");
    if (!img) return;

    // Replace the filename target content with the image
    this.fileNameTarget.innerHTML = "";
    const clone = img.cloneNode(true);

    this.fileNameTarget.appendChild(clone);
  }
}
