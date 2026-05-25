import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  static values = { model: String, exclude: String };

  connect() {
    this.select = new TomSelect(this.element, {
      valueField: "id",
      labelField: "label",
      searchField: "label",
      score: () => () => 1,
      create: false,
      load: (query, callback) => {
        if (!query.length) return callback();

        this.select.clearOptions();
        let url = `/search/${this.modelValue}?q=${encodeURIComponent(query)}`;

        if (this.hasExcludeValue && this.excludeValue) {
          url += `&exclude=${encodeURIComponent(this.excludeValue)}`;
        }
        fetch(url)
          .then((r) => r.json())
          .then((json) => callback(json))
          .catch(() => callback());
      },
    });
    // Inject CSS to remove some default tom-select styles -might be a better way to do this.
    const style = document.createElement("style");
    style.textContent = `
      /* Remove border and shadow */
      .ts-control .ts-input,
      .ts-control input {
        border: none !important;
        box-shadow: none !important;
        outline: none !important;
        background: transparent !important;
        padding: 0 !important;           /* Remove padding from input */
        margin: 0 !important;            /* Remove margin if any */
        line-height: 1.5rem !important;  /* Match the line-height of a native input so heights align */
      }
      .ts-control {
        border: none !important;
        box-shadow: none !important;
        padding: 0 !important;           /* Remove padding from container */
        margin: 0 !important;
        min-height: 1.5rem !important;   /* Match a single line of text so empty state matches selected state */
        line-height: 1.5rem !important;
      }
      .ts-control .item {
        margin: 0 !important;            /* Remove padding/margin from selected items */
        padding: 0 !important;
        line-height: 1.5rem !important;
      }
    `;
    document.head.appendChild(style);
  }

  disconnect() {
    if (this.select) this.select.destroy();
  }
}
