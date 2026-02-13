import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.css";

// Connects to data-controller="searchable-select"
// Makes a <select> searchable via Tom Select. Put the controller on a wrapper
// and add data-searchable-select-target="select" to the select element.
export default class extends Controller {
  static targets = ["select"];

  connect() {
    if (!this.hasSelectTarget) return;

    const el = this.selectTarget;
    if (el._tomSelect) return; // already initialized (e.g. Turbo cache)

    this.tomSelect = new TomSelect(el, {
      allowEmptyOption: true,
      placeholder: this.placeholderValue || "Search…",
      maxOptions: null,
    });
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy();
      this.tomSelect = null;
    }
  }

  static values = {
    placeholder: { type: String, default: "Search…" },
  };
}

