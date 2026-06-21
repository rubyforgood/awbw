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
  static targets = ["endDate", "title", "row", "profileButton", "stripe"]

  connect() {
    // Save original classes for profile buttons and their styled children
    this._savedClasses = [];
    this.profileButtonTargets.forEach((btn) => {
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
    if (this.hasStripeTarget) {
      this.stripeTarget.style.backgroundColor = this.isFacilitator() ? "#a855f7" : "#d1d5db";
    }
    this.updateRowBackground();
  }

  apply() {
    if (!this.hasEndDateTarget) return;
    const isPast = this.isPast();

    this.updateRowBackground();

    if (isPast) {
      this.profileButtonTargets.forEach((btn) => {
        btn.querySelectorAll("a.group, a.group span").forEach((el) => grayOut(el));
      });
    } else {
      this._savedClasses.forEach(({ el, className }) => { el.className = className; });
    }
  }

  // Single source of truth for the row tint: gray when expired, light purple for
  // an active facilitator, white otherwise.
  updateRowBackground() {
    this.rowTarget.classList.remove(
      "bg-gray-100", "border-gray-300", "opacity-60",
      "bg-purple-100", "border-purple-300",
      "bg-white", "border-gray-200"
    );

    if (this.isPast()) {
      this.rowTarget.classList.add("bg-gray-100", "border-gray-300", "opacity-60");
    } else if (this.isFacilitator()) {
      this.rowTarget.classList.add("bg-purple-100", "border-purple-300");
    } else {
      this.rowTarget.classList.add("bg-white", "border-gray-200");
    }
  }

  isPast() {
    if (!this.hasEndDateTarget) return false;
    const value = this.endDateTarget.value;
    return value && new Date(value) < new Date(new Date().toDateString());
  }

  // Mirror Affiliation#facilitator? — an exact, case-sensitive match on
  // "Facilitator" (trimmed), so the live row tint matches what the server will render.
  isFacilitator() {
    return this.hasTitleTarget && this.titleTarget.value.trim() === "Facilitator";
  }
}
