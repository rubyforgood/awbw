import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  static values = { model: String, exclude: String };

  get personModel() {
    return this.modelValue === "person" || this.modelValue === "user";
  }

  connect() {
    const options = {
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
          .then((json) => {
            callback(json);
            this.updateScrollHint();
          })
          .catch(() => callback());
      },
    };

    if (this.personModel) {
      const renderFn = (data, escape) => {
        const match = data.label.match(/^(.+?)\s*\(([^)]+)\)\s*$/);
        if (match) {
          return `<div><span style="font-weight:600;color:#111827">${escape(match[1].trim())}</span> <span style="color:#9ca3af">(${escape(match[2])})</span></div>`;
        }
        return `<div><span style="font-weight:600;color:#111827">${escape(data.label)}</span></div>`;
      };
      options.render = { option: renderFn, item: renderFn };
    }

    this.select = new TomSelect(this.element, options);
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
      .ts-dropdown-content {
        max-height: 400px !important;
        overflow-y: auto !important;
      }
      .ts-dropdown .scroll-hint {
        text-align: center;
        padding: 4px 0;
        color: #9ca3af;
        font-size: 0.75rem;
        border-top: 1px solid #e5e7eb;
        background: #f9fafb;
      }
    `;
    document.head.appendChild(style);
  }

  updateScrollHint() {
    requestAnimationFrame(() => {
      const dropdown = this.select.dropdown;
      if (!dropdown) return;

      const content = dropdown.querySelector(".ts-dropdown-content");
      if (!content) return;

      const existing = dropdown.querySelector(".scroll-hint");
      if (existing) existing.remove();

      if (content.scrollHeight > content.clientHeight) {
        const hint = document.createElement("div");
        hint.className = "scroll-hint";
        hint.textContent = `Scroll for more results`;
        dropdown.appendChild(hint);
      }
    });
  }

  disconnect() {
    if (this.select) this.select.destroy();
  }
}
