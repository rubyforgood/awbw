import { Controller } from "@hotwired/stimulus";

// Live row tint for the affiliation editor: reflects facilitator-ness (title) and
// active/expired state (end date) as you edit, before saving. The person/org pill
// and field chrome are static neutral styles now, so only the row background and
// the left accent bar need updating here.
export default class extends Controller {
  static targets = ["endDate", "title", "row", "accentBar"]
  static values = { activeTint: String }

  connect() {
    if (this.hasEndDateTarget) this.apply();
    if (this.hasTitleTarget) this.updateBorder();
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
    this.styleTitle(facilitator);
    this.updateRowBackground();
  }

  // Purple "Facilitator" tint on the title input, matching the server-rendered
  // state and toggled live as the title changes. Shape/size are untouched.
  styleTitle(facilitator) {
    const t = this.titleTarget;
    t.classList.toggle("bg-purple-100!", facilitator);
    t.classList.toggle("text-purple-700!", facilitator);
    t.classList.toggle("font-semibold", facilitator);
    t.classList.toggle("border-purple-300!", facilitator);
    t.classList.toggle("border-gray-300!", !facilitator);
  }

  apply() {
    if (!this.hasEndDateTarget) return;
    this.updateRowBackground();
  }

  // Single source of truth for the row tint: gray when expired, light purple for
  // an active facilitator, else the counterpart-theme active tint (sky/emerald).
  updateRowBackground() {
    const activeTint = (this.activeTintValue || "bg-white border-gray-200").split(" ");
    this.rowTarget.classList.remove(
      "bg-gray-100", "border-gray-300", "opacity-60",
      "bg-purple-50", "border-purple-200",
      "bg-sky-50", "border-sky-200",
      "bg-emerald-50", "border-emerald-200",
      "bg-white", "border-gray-200"
    );

    if (this.isPast()) {
      this.rowTarget.classList.add("bg-gray-100", "border-gray-300", "opacity-60");
    } else if (this.isFacilitator()) {
      this.rowTarget.classList.add("bg-purple-50", "border-purple-200");
    } else {
      this.rowTarget.classList.add(...activeTint);
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
