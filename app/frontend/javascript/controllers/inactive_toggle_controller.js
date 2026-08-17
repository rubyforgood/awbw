import { Controller } from "@hotwired/stimulus";

// Live styling for the affiliation editor row: reflects facilitator-ness (title)
// and active/expired state (end date) as you edit, before saving. Drives the row
// tint, the left accent bar, the "Facilitator" title purple, and the field fills
// (transparent when empty, the pill colour when filled).
export default class extends Controller {
  static targets = ["endDate", "title", "row", "accentBar", "valueField"]
  static values = { activeTint: String, expired: Boolean }

  connect() {
    if (this.hasEndDateTarget) this.apply();
    if (this.hasTitleTarget) this.updateBorder();
    this.paintFields();
  }

  toggle() {
    this.apply();
  }

  updateBorder() {
    if (!this.hasTitleTarget) return;
    const facilitator = this.isFacilitator();
    if (this.hasAccentBarTarget) {
      this.accentBarTarget.classList.toggle("bg-purple-500", facilitator);
      this.accentBarTarget.classList.toggle("bg-gray-300", !facilitator);
    }
    this.styleTitle();
    this.updateRowBackground();
    this.paintFields();
  }

  apply() {
    if (!this.hasEndDateTarget) return;
    this.updateRowBackground();
    this.styleTitle();
    this.paintFields();
  }

  // The "Facilitator" title keeps its own darker purple (lighter when inactive);
  // any other title fills like the rest of the fields. Shape/size are untouched.
  styleTitle() {
    if (!this.hasTitleTarget) return;
    const t = this.titleTarget;
    const facilitator = this.isFacilitator();
    const past = this.isPast();
    t.classList.remove(
      "bg-transparent!", "bg-gray-100!", "bg-white!", "bg-purple-100!", "bg-purple-50!",
      "text-purple-700!", "text-purple-400!", "font-semibold",
      "border-purple-300!", "border-purple-200!", "border-gray-300!"
    );
    if (facilitator && !past) {
      t.classList.add("bg-purple-100!", "text-purple-700!", "font-semibold", "border-purple-300!");
    } else if (facilitator && past) {
      t.classList.add("bg-purple-50!", "text-purple-400!", "border-purple-200!");
    } else {
      t.classList.add(this.fieldBg(t), "border-gray-300!");
    }
  }

  // Repaint the date/address fields: empty -> transparent (card tint shows
  // through), filled -> the pill colour for the row's current state.
  paintFields() {
    this.valueFieldTargets.forEach((el) => {
      el.classList.remove("bg-transparent!", "bg-gray-100!", "bg-white!", "bg-purple-100!", "bg-purple-50!");
      el.classList.add(this.fieldBg(el));
    });
  }

  fieldBg(el) {
    return this.fieldHasValue(el) ? this.pillColorClass() : "bg-transparent!";
  }

  // The fill for a filled field: facilitator rows take purple (lighter when
  // inactive to match the title), other rows take white (active) / grey (inactive).
  pillColorClass() {
    if (this.isFacilitator()) return this.isPast() ? "bg-purple-50!" : "bg-purple-100!";
    return this.isPast() ? "bg-gray-100!" : "bg-white!";
  }

  fieldHasValue(el) {
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") return el.value.trim() !== "";
    // Address button: filled when its org-address hidden input holds a value.
    const hidden = el.parentElement.querySelector("input[type='hidden']");
    return Boolean(hidden && hidden.value);
  }

  // Single source of truth for the row tint: gray when expired, light purple for
  // an active facilitator, else the counterpart-theme active tint (sky/emerald).
  updateRowBackground() {
    const activeTint = (this.activeTintValue || "bg-gray-50 border-gray-200").split(" ");
    this.rowTarget.classList.remove(
      "bg-gray-100", "border-gray-300", "opacity-60",
      "bg-purple-50", "border-purple-200",
      "bg-gray-50", "border-gray-200"
    );

    if (this.isPast()) {
      if (this.isFacilitator()) {
        this.rowTarget.classList.add("bg-purple-50", "border-purple-200", "opacity-60");
      } else {
        this.rowTarget.classList.add("bg-gray-100", "border-gray-300", "opacity-60");
      }
    } else if (this.isFacilitator()) {
      this.rowTarget.classList.add("bg-purple-50", "border-purple-200");
    } else {
      this.rowTarget.classList.add(...activeTint);
    }
  }

  // With an end date, compute from it (live); without one, the JS can't see the
  // server's inactive flag, so trust the server-rendered `expired` value.
  isPast() {
    const value = this.hasEndDateTarget ? this.endDateTarget.value : "";
    if (value) return new Date(value) < new Date(new Date().toDateString());
    return this.expiredValue;
  }

  // Mirror Affiliation#facilitator? — an exact, case-sensitive match on
  // "Facilitator" (trimmed), so the live row tint matches what the server will render.
  isFacilitator() {
    return this.hasTitleTarget && this.titleTarget.value.trim() === "Facilitator";
  }
}
