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
    this.addSearchIcon();
    this.injectStyles();
  }

  // Inject CSS to remove some default tom-select styles -might be a better way to do this.
  // Gated on an id so repeated connects (Turbo nav, cocoon add, reconnect) don't append duplicates.
  injectStyles() {
    const styleId = "remote-select-styles";
    if (document.getElementById(styleId)) return;
    const style = document.createElement("style");
    style.id = styleId;
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
      .remote-select-container {
        position: relative;
        width: 100%;
      }
      .remote-select-container .ts-wrapper {
        width: 100%;
      }
      .remote-select-container .remote-select-icon {
        position: absolute;
        left: 0.75rem;
        top: 50%;
        transform: translateY(-50%);
        color: #9ca3af;
        font-size: 0.875rem;
        line-height: 1;
        pointer-events: none;
        z-index: 1;
      }
      .remote-select-container .ts-control {
        padding-left: 1.5rem !important;  /* Make room for the search icon */
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
      /* Opaque white field so colored card backgrounds don't show through */
      .remote-select-container .ts-wrapper,
      .remote-select-container .ts-control {
        background-color: #fff !important;
      }
    `;
    document.head.appendChild(style);
  }

  addSearchIcon() {
    const wrapper = this.select.wrapper;
    if (!wrapper || wrapper.parentElement?.classList.contains("remote-select-container")) return;
    const container = document.createElement("div");
    container.className = "remote-select-container";
    wrapper.parentNode.insertBefore(container, wrapper);
    container.appendChild(wrapper);
    const icon = document.createElement("i");
    icon.className = "fa-solid fa-magnifying-glass remote-select-icon";
    icon.setAttribute("aria-hidden", "true");
    container.appendChild(icon);
  }

  // Deselect the current value so the control is ready for the next pick.
  // Used by controllers (e.g. org-toggle) that consume a selection and want
  // to reuse the same search box to add another.
  clear() {
    if (this.select) this.select.clear();
  }

  disconnect() {
    if (this.select) this.select.destroy();
  }
}
