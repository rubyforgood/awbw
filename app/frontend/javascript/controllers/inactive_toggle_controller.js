import { Controller } from "@hotwired/stimulus";

// Live styling for the affiliation editor row as you edit, before saving. Colour
// carries role only (facilitator = purple, else neutral); inactive is a structural
// cue — a dashed row border and a struck-through end date — so active vs inactive
// never competes with the role colour.
export default class extends Controller {
  static targets = ["endDate", "title", "row", "accentBar", "valueField"]
  static values = { expired: Boolean }

  connect() {
    if (this.hasTitleTarget) this.updateBorder();
    else this.apply();
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
    this.apply();
  }

  apply() {
    this.updateRowBackground();
    this.styleTitle();
    this.paintFields();
    this.styleEndDate();
  }

  // Facilitator title keeps its darker purple; any other title fills like the rest.
  styleTitle() {
    if (!this.hasTitleTarget) return;
    const t = this.titleTarget;
    t.classList.remove(
      "bg-transparent!", "bg-white!", "bg-purple-100!",
      "text-purple-700!", "font-semibold", "border-purple-300!", "border-gray-300!"
    );
    if (this.isFacilitator()) {
      t.classList.add("bg-purple-100!", "text-purple-700!", "font-semibold", "border-purple-300!");
    } else {
      t.classList.add(this.fieldBg(t), "border-gray-300!");
    }
  }

  // Empty fields are transparent (row tint shows through); filled fields take the
  // role colour (purple for facilitators, else white).
  paintFields() {
    this.valueFieldTargets.forEach((el) => {
      el.classList.remove("bg-transparent!", "bg-white!", "bg-purple-100!");
      el.classList.add(this.fieldBg(el));
    });
  }

  fieldBg(el) {
    if (!this.fieldHasValue(el)) return "bg-transparent!";
    return this.isFacilitator() ? "bg-purple-100!" : "bg-white!";
  }

  fieldHasValue(el) {
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") return el.value.trim() !== "";
    // Address button: filled when its org-address hidden input holds a value.
    const hidden = el.parentElement.querySelector("input[type='hidden']");
    return Boolean(hidden && hidden.value);
  }

  // Role colour for the row + a dashed border when inactive.
  updateRowBackground() {
    const facilitator = this.isFacilitator();
    const past = this.isPast();
    this.rowTarget.classList.remove(
      "bg-purple-50", "bg-gray-50",
      "border-purple-200", "border-purple-300", "border-gray-200", "border-gray-300",
      "border-dashed"
    );
    this.rowTarget.classList.add(facilitator ? "bg-purple-50" : "bg-gray-50");
    if (past) {
      this.rowTarget.classList.add(facilitator ? "border-purple-300" : "border-gray-300", "border-dashed");
    } else {
      this.rowTarget.classList.add(facilitator ? "border-purple-200" : "border-gray-200");
    }
  }

  // Strike the end date when it marks the row ended.
  styleEndDate() {
    if (!this.hasEndDateTarget) return;
    const ended = Boolean(this.endDateTarget.value) && this.isPast();
    this.endDateTarget.classList.toggle("date-ended", ended);
  }

  // With an end date, compute from it (live); without one, the JS can't see the
  // server's inactive flag, so trust the server-rendered `expired` value.
  isPast() {
    const value = this.hasEndDateTarget ? this.endDateTarget.value : "";
    if (value) return new Date(value) < new Date(new Date().toDateString());
    return this.expiredValue;
  }

  // Mirror Affiliation#facilitator? — an exact, case-sensitive match on
  // "Facilitator" (trimmed), so the live styling matches what the server renders.
  isFacilitator() {
    return this.hasTitleTarget && this.titleTarget.value.trim() === "Facilitator";
  }
}
