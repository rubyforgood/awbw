import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.css";

// Connects to data-controller="grant-select"
// A searchable grant picker built on Tom Select. Put the controller on a wrapper
// and add data-grant-select-target="select" to the <select>.
//
// Each <option> text is "Grant name (Funder)" and may carry data-remaining /
// data-total compact amounts (e.g. "$4k" / "$45k") plus a data-summary tooltip.
// The open list bolds the name, grays the funder, and shows a green pill with the
// remaining funds bold and the total muted ("$4k of $45k"); the collapsed
// selection stays compact.
export default class extends Controller {
  static targets = ["select"];

  static values = {
    placeholder: { type: String, default: "None" },
  };

  connect() {
    if (!this.hasSelectTarget) return;

    const el = this.selectTarget;
    if (el._tomSelect) return; // already initialized (e.g. Turbo cache)

    this.tomSelect = new TomSelect(el, {
      allowEmptyOption: true,
      placeholder: this.placeholderValue,
      maxOptions: null,
      // Announce the chosen grant so grant-details can swap in its criteria/tasks.
      onChange: (value) => {
        this.dispatch("change", { detail: { grantId: value }, bubbles: true });
      },
      render: {
        option: (data, escape) => {
          // Wrap name + funder so they stay grouped on the left; space-between
          // then pushes only the remaining-funds badge to the right. Without the
          // wrapper the two text spans and the badge become three flex children
          // and the funder gets stranded in the center.
          return `<div style="display:flex;align-items:center;justify-content:space-between;gap:0.5rem"><span>${nameAndFunder(data.text, escape)}</span>${fundsBadge(data, escape)}</div>`;
        },
        // Selected row mirrors the option layout (full width so space-between
        // pushes the funds badge to the field's right edge).
        item: (data, escape) =>
          `<div style="display:flex;align-items:center;justify-content:space-between;gap:0.5rem;width:100%"><span>${nameAndFunder(data.text, escape)}</span>${fundsBadge(data, escape)}</div>`,
      },
    });

    // TomSelect copies the field's border/padding onto its wrapper while its inner
    // .ts-control keeps a default border + background — a nested "box in a box".
    // Flatten the inner control so only the wrapper reads as the field.
    this.tomSelect.wrapper.classList.add("grant-select-flat");
    injectFlatStyles();

    // Clear empty selection so the placeholder shows in grey.
    if (!el.value) {
      this.tomSelect.clear(true);
    }
  }

  disconnect() {
    if (this.tomSelect) {
      this.tomSelect.destroy();
      this.tomSelect = null;
    }
  }
}

const badgeStyle = "white-space:nowrap;font-size:0.7rem;color:#15803d;background:#f0fdf4;border:1px solid #bbf7d0;border-radius:9999px;padding:0.05rem 0.5rem";

// Green pill summarising a grant's funds: the remaining balance bold (the figure
// that matters), the total muted alongside — e.g. "$4k of $45k". The full
// "$4k of $45k available" sits in the title for tooltip/screen-reader context.
function fundsBadge(data, escape) {
  if (!data.remaining) return "";
  const total = data.total
    ? ` <span style="font-weight:400;opacity:0.7">of ${escape(data.total)}</span>`
    : "";
  const title = data.summary ? ` title="${escape(data.summary)}"` : "";
  return `<span${title} style="${badgeStyle}"><span style="font-weight:700">${escape(data.remaining)}</span>${total}</span>`;
}

// Strip TomSelect's default inner-control chrome (border, background, padding) so
// the picker reads as a single field rather than a box nested in a box. Injected
// once and shared by every grant-select instance on the page.
function injectFlatStyles() {
  if (document.getElementById("grant-select-flat-styles")) return;
  const style = document.createElement("style");
  style.id = "grant-select-flat-styles";
  style.textContent = `
    .grant-select-flat .ts-control {
      border: none !important;
      background: transparent !important;
      box-shadow: none !important;
      padding: 0 !important;
      min-height: 1.5rem !important;
      align-items: center !important;
      flex-wrap: nowrap !important;
    }
    .grant-select-flat .ts-control .item {
      border: none !important;
      background: transparent !important;
      margin: 0 !important;
      padding: 0 !important;
    }
    /* The search input defaults to min-width:7rem; alongside a long grant name it
       wraps to a second line and leaves empty space below the text. min-width:0
       lets it shrink onto the same line so the selection stays vertically centered. */
    .grant-select-flat .ts-control > input {
      min-width: 0 !important;
    }
  `;
  document.head.appendChild(style);
}

// "Grant name (Funder)" -> bold name + gray funder.
function nameAndFunder(text, escape) {
  const match = text.match(/^(.+?)\s*\(([^)]+)\)\s*$/);
  const name = match ? match[1].trim() : text;
  const funder = match ? match[2] : null;
  let html = `<span style="font-weight:600;color:#111827">${escape(name)}</span>`;
  if (funder) html += ` <span style="color:#9ca3af">(${escape(funder)})</span>`;
  return html;
}
