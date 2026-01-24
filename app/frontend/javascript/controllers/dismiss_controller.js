import { Controller } from "@hotwired/stimulus";

/**
 * Dismissible UI elements (flash messages, alerts, banners).
 *
 * - Click on close button -> instant remove
 * - Click anywhere else on page -> instant remove (optional, enabled by default)
 * - Optional timeout -> fade out, then remove
 * - Supports all (click cancels timer)
 *
 * <div
 *   data-controller="dismiss"
 *   data-dismiss-timeout-value="8000"
 *   data-action="click->dismiss#hide"
 *   data-dismiss-disable-outside-click-value="false"
 * >
 *   All behaviors
 * </div>
 */

// Connects to data-controller="dismiss"

export default class extends Controller {
  static values = { timeout: Number, disableOutsideClick: Boolean };

  connect() {
    if (this.hasTimeoutValue) {
      this.timeoutId = setTimeout(
        () => this.fadeOutAndRemove(),
        this.timeoutValue,
      );
    }

    // Set up outside click handler if enabled
    if (!this.disableOutsideClickValue) {
      this.outsideClickHandler = (event) => this.handleOutsideClick(event);
      document.addEventListener("click", this.outsideClickHandler);
    }
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.hide();
    }
  }

  hide() {
    if (this.timeoutId) clearTimeout(this.timeoutId);
    if (this.outsideClickHandler) {
      document.removeEventListener("click", this.outsideClickHandler);
    }
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
    if (this.outsideClickHandler) {
      document.removeEventListener("click", this.outsideClickHandler);
    }
  }
}
