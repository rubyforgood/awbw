import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  static values = { model: String };

  connect() {
    this.select = new TomSelect(this.element, {
      valueField: "id",
      labelField: "label",
      searchField: "label",
      create: false,
      load: (query, callback) => {
        if (!query.length) return callback();

        fetch(`/search/${this.modelValue}?q=${encodeURIComponent(query)}`)
          .then((r) => r.json())
          .then((json) => callback(json))
          .catch(() => callback());
      },
    });
    // Inject CSS to remove some default tom-select styles -might be a better way to do this.
    const style = document.createElement("style");
    style.textContent = `
      /* Remove border and shadow */
      .ts-control .ts-input {
        border: none !important;
        box-shadow: none !important;
        outline: none !important;
        background: transparent !important;
        padding: 0 !important;           /* Remove padding from input */
        margin: 0 !important;            /* Remove margin if any */
      }
      .ts-control {
        border: none !important;
        box-shadow: none !important;
        padding: 0 !important;           /* Remove padding from container */
        margin: 0 !important;
        min-height: 0 !important;        /* Remove min-height TomSelect sets */
      }
      .ts-control .item {
        margin: 0 !important;            /* Remove padding/margin from selected items */
        padding: 0 !important;
      }
    `;
    document.head.appendChild(style);
  }

  disconnect() {
    if (this.select) this.select.destroy();
  }
}
