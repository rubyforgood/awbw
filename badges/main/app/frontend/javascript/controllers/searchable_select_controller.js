import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.css";

// Connects to data-controller="searchable-select"
// Makes a <select> searchable via Tom Select. Put the controller on a wrapper
// and add data-searchable-select-target="select" to the select element.
//
// Use data-searchable-select-mode-value="person" for person dropdowns to render
// the name in bold and the email in gray.
export default class extends Controller {
  static targets = ["select"];

  connect() {
    if (!this.hasSelectTarget) return;

    const el = this.selectTarget;
    if (el._tomSelect) return; // already initialized (e.g. Turbo cache)

    const options = {
      allowEmptyOption: true,
      placeholder: this.placeholderValue || "Search…",
      maxOptions: null,
    };

    if (this.modeValue === "person") {
      const renderFn = (data, escape) => {
        const match = data.text.match(/^(.+?)\s*\(([^)]+)\)\s*$/);
        if (match) {
          return `<div><span style="font-weight:600;color:#111827">${escape(match[1].trim())}</span> <span style="color:#9ca3af">(${escape(match[2])})</span></div>`;
        }
        return `<div><span style="font-weight:600;color:#111827">${escape(data.text)}</span></div>`;
      };
      options.render = { option: renderFn, item: renderFn };
    }

    this.tomSelect = new TomSelect(el, options);
  }

  submit() {
    this.element.closest("form")?.submit();
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy();
      this.tomSelect = null;
    }
  }

  static values = {
    placeholder: { type: String, default: "Search…" },
    mode: { type: String, default: "" },
  };
}
