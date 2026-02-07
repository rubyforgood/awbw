import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="asset-upload"
export default class extends Controller {
  static targets = [
    "fileInput",
    "form",
    "typeSelect",

    "uploadButtonPrimary",
    "uploadLabelPrimary",
    "primaryDeleteButton",

    "uploadButtonDownloadable",
    "uploadLabelDownloadable",
    "downloadableDeleteButton",
  ];

  // Store the dom_id of currently uploaded primary/downloadable assets
  primaryAssetId = null;
  downloadableAssetId = null;

  connect() {
    const primary = document.querySelector("[id*='primary_asset_']");
    if (primary) {
      this.replacePreview(this.uploadLabelPrimaryTarget, primary);
      this.uploadButtonPrimaryTarget.classList.add("hidden");
      this.primaryDeleteButtonTarget.classList.remove("hidden");
      this.primaryAssetId = primary.id;
    }
    const downloadable = document.querySelector("[id*='downloadable_asset_']");
    if (downloadable) {
      this.replacePreview(this.uploadLabelDownloadableTarget, downloadable);
      this.uploadButtonDownloadableTarget.classList.add("hidden");
      this.downloadableDeleteButtonTarget.classList.remove("hidden");
      this.downloadableAssetId = downloadable.id;
    }
  }
  /* ─────────────────────────────
   * Upload intent (pre-submit)
   * ───────────────────────────── */

  triggerFileInput({ params: { type } }) {
    this.selectedType = type;
    this.fileInputTarget.click();
  }

  handleFileChange() {
    console.log(this.fileInputTarget);
    if (this.fileInputTarget.files.length === 0) {
      this.selectedType = "GalleryAsset";
      if (this.hasTypeSelectTarget)
        this.typeSelectTarget.value = this.selectedType;
      return;
    }
    console.log(this.typeSelectTarget.value);
    if (this.hasTypeSelectTarget && this.selectedType) {
      this.typeSelectTarget.value = this.selectedType;
    }

    this.showSpinner();
    this.formTarget.requestSubmit();
    // Reset
    this.selectedType = "GalleryAsset";
  }

  showSpinner() {
    const spinner = `<i class="fa-solid fa-spinner animate-spin text-gray-600 text-5xl"></i>`;

    if (
      this.selectedType === "PrimaryAsset" &&
      this.hasUploadLabelPrimaryTarget
    ) {
      this.uploadLabelPrimaryTarget.innerHTML = spinner;
    }

    if (
      this.selectedType === "DownloadableAsset" &&
      this.hasUploadLabelDownloadableTarget
    ) {
      this.uploadLabelDownloadableTarget.innerHTML = spinner;
    }
  }

  /* ─────────────────────────────
   * Turbo event handling for new frames and stream removes
   * ───────────────────────────── */

  handleFrameLoad(event) {
    const frame = event.target;
    const candidates = frame.querySelectorAll("[id*='_asset_']");
    const cards = Array.from(candidates).filter((el) => {
      // Only match IDs that contain "_asset_" and end with numbers
      return /_asset_\d+$/.test(el.id);
    });

    this.handleCards(cards);
  }

  handleStream(event) {
    const stream = event.target;
    if (stream.target == "assets") {
      const template = stream.querySelector("template");
      const candidates = template.content.querySelectorAll("[id*='_asset_']");
      const cards = Array.from(candidates).filter((el) => {
        // Only match IDs that contain "_asset_" and end with numbers
        return /_asset_\d+$/.test(el.id);
      });
      this.handleCards(cards);
      return;
    }
    if (stream.action !== "remove") return;

    const role = this.roleFromId(stream.target);
    if (!role) return;

    this.assetRemoved({
      detail: {
        id: stream.target,
        role: role,
      },
    });
  }

  handleCards(cards) {
    cards.forEach((card) => {
      const role = this.roleFromId(card.id);
      if (!role) return;

      // Trigger assetAdded internally
      this.assetAdded({
        detail: {
          id: card.id,
          role: role,
          element: card,
        },
      });
    });
  }
  /* ─────────────────────────────
   * Asset Added / Removed
   * ───────────────────────────── */

  assetAdded(event) {
    const { role, element } = event.detail;
    const id = event.detail.id || (element ? element.id : null);
    if (!id) return;

    if (role === "primary") {
      this.replacePreview(this.uploadLabelPrimaryTarget, element);
      this.uploadButtonPrimaryTarget.classList.add("hidden");
      this.primaryDeleteButtonTarget.classList.remove("hidden");
      this.primaryAssetId = id; // store dom_id
    }

    if (role === "downloadable") {
      this.replacePreview(this.uploadLabelDownloadableTarget, element);
      this.uploadButtonDownloadableTarget.classList.add("hidden");
      this.downloadableDeleteButtonTarget.classList.remove("hidden");
      this.downloadableAssetId = id; // store dom_id
    }
  }

  assetRemoved(event) {
    const { role } = event.detail;

    if (role === "primary") {
      this.resetPreview(this.uploadLabelPrimaryTarget);
      this.uploadButtonPrimaryTarget.classList.remove("hidden");
      this.primaryDeleteButtonTarget.classList.add("hidden");
      this.primaryAssetId = null;
    }

    if (role === "downloadable") {
      this.resetPreview(this.uploadLabelDownloadableTarget);
      this.uploadButtonDownloadableTarget.classList.remove("hidden");
      this.downloadableDeleteButtonTarget.classList.add("hidden");
      this.downloadableAssetId = null;
    }
  }

  /* ─────────────────────────────
   * Preview helpers
   * ───────────────────────────── */

  replacePreview(target, card) {
    if (!target) return;

    const img = card.querySelector("img");
    if (!img) return;

    target.innerHTML = "";
    target.appendChild(img.cloneNode(true));
  }

  resetPreview(target) {
    if (!target) return;

    target.innerHTML = `
      <svg class="w-16 h-16 cursor-pointer">
        <!-- default upload icon -->
      </svg>
    `;
  }

  /* ─────────────────────────────
   * Fake X button handlers
   * ───────────────────────────── */

  removeFakePrimary() {
    if (!this.primaryAssetId) return;

    this.resetPreview(this.uploadLabelPrimaryTarget);
    this.uploadButtonPrimaryTarget.classList.remove("hidden");

    const card = document.getElementById(this.primaryAssetId);
    if (!card) return;

    const deleteForm = Array.from(card.querySelectorAll("form.button_to")).find(
      (form) => {
        const methodInput = form.querySelector("input[name='_method']");
        return methodInput && methodInput.value.toLowerCase() === "delete";
      },
    );

    if (deleteForm) deleteForm.requestSubmit();
    this.primaryAssetId = null;
  }

  removeFakeDownloadable() {
    if (!this.downloadableAssetId) return;

    this.resetPreview(this.uploadLabelDownloadableTarget);
    this.uploadButtonDownloadableTarget.classList.remove("hidden");

    const card = document.getElementById(this.downloadableAssetId);
    if (!card) return;

    const deleteForm = Array.from(card.querySelectorAll("form.button_to")).find(
      (form) => {
        const methodInput = form.querySelector("input[name='_method']");
        return methodInput && methodInput.value.toLowerCase() === "delete";
      },
    );

    if (deleteForm) deleteForm.requestSubmit();
    this.downloadableAssetId = null;
  }

  /* ─────────────────────────────
   * Utility: determine role from id
   * ───────────────────────────── */

  roleFromId(id) {
    console.log(id);
    if (!id) return null;
    if (id.startsWith("primary_asset_")) return "primary";
    if (id.startsWith("downloadable_asset_")) return "downloadable";
    if (id.startsWith("gallery_asset_")) return "gallery";
    return null;
  }
}
