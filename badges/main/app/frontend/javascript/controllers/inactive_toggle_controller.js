import { Controller } from "@hotwired/stimulus";

// Live styling for the affiliation editor row as you edit, before saving. Four
// states by colour: role is the hue (facilitator = purple, else blue) and status
// is the saturation (active = full, inactive = super-light). Inactive rows also
// strike their fields (.aff-ended).
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
    if (this.hasAccentBarTarget) {
      const fac = this.isFacilitator();
      const past = this.isPast();
      const a = this.accentBarTarget.classList;
      a.toggle("bg-purple-500", fac && !past);
      a.toggle("bg-purple-300", fac && past);
      a.toggle("bg-blue-500", !fac && !past);
      a.toggle("bg-blue-300", !fac && past);
    }
    this.apply();
  }

  apply() {
    this.updateRowBackground();
    this.styleTitle();
    this.paintFields();
    this.rowTarget.classList.toggle("aff-ended", this.isPast());
  }

  styleTitle() {
    if (!this.hasTitleTarget) return;
    const t = this.titleTarget;
    const fac = this.isFacilitator();
    const past = this.isPast();
    t.classList.remove(
      "bg-purple-100!", "bg-purple-50!", "bg-blue-100!", "bg-blue-50!",
      "text-purple-700!", "text-purple-500!", "text-blue-700!", "text-blue-500!",
      "font-semibold",
      "border-purple-300!", "border-purple-200!", "border-blue-300!", "border-blue-200!"
    );
    if (fac && !past) t.classList.add("bg-purple-100!", "text-purple-700!", "font-semibold", "border-purple-300!");
    else if (fac && past) t.classList.add("bg-purple-50!", "text-purple-500!", "border-purple-200!");
    else if (!fac && !past) t.classList.add("bg-blue-100!", "text-blue-700!", "font-semibold", "border-blue-300!");
    else t.classList.add("bg-blue-50!", "text-blue-500!", "border-blue-200!");
  }

  // Empty fields are transparent (row tint shows through); filled fields take the
  // role+status fill colour.
  paintFields() {
    this.valueFieldTargets.forEach((el) => {
      el.classList.remove("bg-transparent!", "bg-purple-100!", "bg-purple-50!", "bg-blue-100!", "bg-blue-50!");
      el.classList.add(this.fieldHasValue(el) ? this.fillClass() : "bg-transparent!");
    });
  }

  fillClass() {
    if (this.isFacilitator()) return this.isPast() ? "bg-purple-50!" : "bg-purple-100!";
    return this.isPast() ? "bg-blue-50!" : "bg-blue-100!";
  }

  fieldHasValue(el) {
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") return el.value.trim() !== "";
    // Address button: filled when its org-address hidden input holds a value.
    const hidden = el.parentElement.querySelector("input[type='hidden']");
    return Boolean(hidden && hidden.value);
  }

  // Row background is the role hue only; status is carried by the fills/accent/title.
  updateRowBackground() {
    const fac = this.isFacilitator();
    const r = this.rowTarget.classList;
    r.remove("bg-purple-50", "border-purple-200", "bg-blue-50", "border-blue-200");
    r.add(fac ? "bg-purple-50" : "bg-blue-50", fac ? "border-purple-200" : "border-blue-200");
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
