import { Controller } from "@hotwired/stimulus";

// Live row tint for the affiliation editor: reflects facilitator-ness (title) and
// active/expired state (end date) as you edit, before saving. The person/org pill
// and field chrome are static neutral styles now, so only the row background and
// the left accent bar need updating here.
export default class extends Controller {
  static targets = ["endDate", "title", "row", "accentBar"]

  connect() {
    if (this.hasEndDateTarget) this.apply();
    if (this.hasTitleTarget) this.updateBorder();
  }

  toggle() {
    this.apply();
  }

  updateBorder() {
    if (!this.hasTitleTarget) return;
    if (this.hasAccentBarTarget) {
      const facilitator = this.isFacilitator();
      this.accentBarTarget.classList.toggle("bg-purple-500", facilitator);
      this.accentBarTarget.classList.toggle("bg-gray-300", !facilitator);
    }
    this.updateRowBackground();
  }

  apply() {
    if (!this.hasEndDateTarget) return;
    this.updateRowBackground();
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
