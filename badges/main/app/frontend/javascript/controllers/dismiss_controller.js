import { Controller } from "@hotwired/stimulus";

/**
 * Dismissible UI elements (flash messages, alerts, banners).
 *
 * - Click -> instant remove
 * - Optional timeout -> fade out, then remove
 * - Supports both (click cancels timer)
 *
 * <div data-controller="dismiss" data-dismiss-timeout-value="8000" data-action="click->dismiss#hide">Both behaviors</div>
 */

// Connects to data-controller="dismiss"

export default class extends Controller {
  static values = { timeout: Number };

  connect() {
    if (this.hasTimeoutValue) {
      this.timeoutId = setTimeout(
        () => this.fadeOutAndRemove(),
        this.timeoutValue,
      );
    }
  }
  hide() {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    this.element.remove();
  }

  fadeOutAndRemove() {
    const fadeDuration = 800;

    this.element.classList.add("opacity-0", "transition-opacity");
    this.element.style.transitionDuration = `${fadeDuration}ms`;

    setTimeout(() => this.element.classList.add("hidden"), fadeDuration);
  }
  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId);
  }
}
