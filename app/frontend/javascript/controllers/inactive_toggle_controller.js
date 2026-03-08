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
  static targets = ["endDate", "title", "row", "button"]

  connect() {
    // Save original classes for profile buttons and their styled children
    this._savedClasses = [];
    this.buttonTargets.forEach((btn) => {
      btn.querySelectorAll("a.group, a.group span").forEach((el) => {
        this._savedClasses.push({ el, className: el.className });
      });
    });

    if (this.hasEndDateTarget) this.apply();
    if (this.hasTitleTarget) this.updateBorder();
  }

  toggle() {
    this.apply();
  }

  updateBorder() {
    if (!this.hasTitleTarget) return;
    const isFacilitator = this.titleTarget.value.toLowerCase().includes("facilitator");
    this.rowTarget.style.borderLeft = `4px solid ${isFacilitator ? "#e879f9" : "#d1d5db"}`;
  }

  apply() {
    if (!this.hasEndDateTarget) return;
    const value = this.endDateTarget.value;
    const isPast = value && new Date(value) < new Date(new Date().toDateString());

    if (isPast) {
      this.rowTarget.classList.add("bg-gray-100", "border-gray-300", "opacity-60");
      this.rowTarget.classList.remove("bg-white", "border-gray-200");
      this.buttonTargets.forEach((btn) => {
        btn.querySelectorAll("a.group, a.group span").forEach((el) => grayOut(el));
      });
    } else {
      this.rowTarget.classList.remove("bg-gray-100", "border-gray-300", "opacity-60");
      this.rowTarget.classList.add("bg-white", "border-gray-200");
      this._savedClasses.forEach(({ el, className }) => { el.className = className; });
    }
  }
}
