import { Controller } from "@hotwired/stimulus";

/*
 * Toggles lock/admin icons in the page title and form labels
 * when the corresponding checkboxes change.
 *
 * Targets:
 *   lockCheckbox  - the lock <input type="checkbox">
 *   lockIcon      - lock icon elements (shown when checked, hidden when unchecked)
 *   lockLabel     - text span toggled between "Lock" / "Locked"
 *   adminCheckbox - the admin <input type="checkbox">
 *   adminIcon     - admin icon elements (shown when checked, hidden when unchecked)
 */
export default class extends Controller {
  static targets = ["lockCheckbox", "lockIcon", "lockLabel", "adminCheckbox", "adminIcon"];

  toggleLock() {
    const locked = this.lockCheckboxTarget.checked;

    if (this.hasLockLabelTarget) {
      this.lockLabelTarget.textContent = locked ? "Locked" : "Lock";
    }

    this.lockIconTargets.forEach((el) => {
      el.style.display = locked ? "" : "none";
    });
  }

  toggleAdmin() {
    const admin = this.adminCheckboxTarget.checked;

    this.adminIconTargets.forEach((el) => {
      el.style.display = admin ? "" : "none";
    });
  }
}
