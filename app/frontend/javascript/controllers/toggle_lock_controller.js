import { Controller } from "@hotwired/stimulus";

/*
 * Toggles lock icons and label text when the "Locked" checkbox changes.
 *
 * Targets:
 *   checkbox  - the <input type="checkbox">
 *   icon      - lock icon elements (shown when checked, removed when unchecked)
 *   labelText - the text span toggled between "Lock" / "Locked"
 */
export default class extends Controller {
  static targets = ["checkbox", "icon", "labelText"];

  toggle() {
    const locked = this.checkboxTarget.checked;

    if (this.hasLabelTextTarget) {
      this.labelTextTarget.textContent = locked ? "Locked" : "Lock";
    }

    this.iconTargets.forEach((el) => {
      el.style.display = locked ? "" : "none";
    });
  }
}
