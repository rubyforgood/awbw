import { Controller } from "@hotwired/stimulus";

const COLORS = "sky|emerald|indigo|purple|teal|violet|orange|rose|blue|pink|cyan|lime|yellow|fuchsia|amber|green|slate|red";
const COLOR_RE = new RegExp(`\\b(hover:)?(bg|text|border)-(${COLORS})-\\d+\\b`, "g");

function grayOut(el) {
  el.className = el.className.replace(COLOR_RE, (_, hover, prop) => {
    if (hover) return "hover:bg-gray-200";
    if (prop === "bg") return "bg-gray-100";
    if (prop === "text") return "text-gray-400";
    if (prop === "border") return "border-gray-300";
    return _;
  });
}

export default class extends Controller {
  connect() {
    this.endDateInput = this.element.querySelector("input[type='date'][name*='end_date']");
    this.titleInput = this.element.querySelector("textarea[name*='title']");

    // Save original classes for profile buttons and their styled children
    this._savedClasses = [];
    this.element.querySelectorAll("a.group, a.group span").forEach((el) => {
      this._savedClasses.push({ el, className: el.className });
    });

    if (this.endDateInput) this.apply();
    if (this.titleInput) this.updateBorder();
  }

  toggle() {
    this.apply();
  }

  updateBorder() {
    if (!this.titleInput) return;
    const isFacilitator = this.titleInput.value.toLowerCase().includes("facilitator");
    this.element.style.borderLeft = `4px solid ${isFacilitator ? "#e879f9" : "#d1d5db"}`;
  }

  apply() {
    if (!this.endDateInput) return;
    const value = this.endDateInput.value;
    const isPast = value && new Date(value) < new Date(new Date().toDateString());

    if (isPast) {
      this.element.classList.add("bg-gray-100", "border-gray-300", "opacity-60");
      this.element.classList.remove("bg-white", "border-gray-200");
      this.element.querySelectorAll("a.group, a.group span").forEach((el) => grayOut(el));
    } else {
      this.element.classList.remove("bg-gray-100", "border-gray-300", "opacity-60");
      this.element.classList.add("bg-white", "border-gray-200");
      this._savedClasses.forEach(({ el, className }) => { el.className = className; });
    }
  }
}
