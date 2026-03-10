import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="dirty-form"
//
// Tracks whether a form has unsaved changes and warns before navigating away.
// Uses three layers of protection:
//   1. turbo:before-visit   - catches Turbo Drive link clicks (custom message)
//   2. beforeunload         - catches non-Turbo navigations / tab close (browser message)
//   3. confirmCancel action - explicit cancel button binding (custom message)
//
export default class extends Controller {
  connect() {
    this.dirty = false;

    // Guard Turbo Drive navigations (links without data-turbo="false")
    this.handleTurboVisit = (event) => {
      if (this.dirty && !confirm("You have unsaved changes. Are you sure you want to leave?")) {
        event.preventDefault();
      }
    };
    document.addEventListener("turbo:before-visit", this.handleTurboVisit);

    // Guard non-Turbo navigations (data-turbo="false" links, browser back, tab close)
    this.handleBeforeUnload = (event) => {
      if (this.dirty) {
        event.preventDefault();
        event.returnValue = "";
      }
    };
    window.addEventListener("beforeunload", this.handleBeforeUnload);
  }

  markDirty() {
    this.dirty = true;
  }

  clearDirty() {
    this.dirty = false;
  }

  confirmCancel(event) {
    if (this.dirty) {
      if (!confirm("You have unsaved changes. Are you sure you want to leave?")) {
        event.preventDefault();
      } else {
        this.dirty = false;
      }
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this.handleTurboVisit);
    window.removeEventListener("beforeunload", this.handleBeforeUnload);
  }
}
