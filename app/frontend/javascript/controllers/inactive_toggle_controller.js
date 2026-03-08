import { Controller } from "@hotwired/stimulus";

// Active themed classes used by person (sky) and organization (emerald) profile buttons
const ACTIVE_CLASSES = [
  "bg-sky-50", "bg-sky-100", "bg-sky-200", "hover:bg-sky-100", "hover:bg-sky-200",
  "text-sky-700", "text-sky-800", "border-sky-200", "border-sky-300",
  "bg-emerald-50", "bg-emerald-100", "bg-emerald-200", "hover:bg-emerald-100", "hover:bg-emerald-200",
  "text-emerald-700", "text-emerald-800", "border-emerald-200", "border-emerald-300"
];
const GRAY_CLASSES = ["bg-gray-100", "hover:bg-gray-200", "text-gray-400", "border-gray-300"];

function grayOut(el) {
  ACTIVE_CLASSES.forEach((cls) => el.classList.remove(cls));
  GRAY_CLASSES.forEach((cls) => el.classList.add(cls));
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
