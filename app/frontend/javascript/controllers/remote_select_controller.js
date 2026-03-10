import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

const STYLE_ID = "remote-select-overrides";

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

    if (!document.getElementById(STYLE_ID)) {
      const style = document.createElement("style");
      style.id = STYLE_ID;
      style.textContent = `
        .ts-control .ts-input {
          border: none !important;
          box-shadow: none !important;
          outline: none !important;
          background: transparent !important;
          padding: 0 !important;
          margin: 0 !important;
        }
        .ts-control {
          border: none !important;
          box-shadow: none !important;
          padding: 0 !important;
          margin: 0 !important;
          min-height: 0 !important;
        }
        .ts-control .item {
          margin: 0 !important;
          padding: 0 !important;
        }
      `;
      document.head.appendChild(style);
    }
  }

  disconnect() {
    if (this.select) this.select.destroy();
  }
}
