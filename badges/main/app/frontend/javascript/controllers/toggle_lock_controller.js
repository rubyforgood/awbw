import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

/*
 * Usage
 * =====
 *
 * Add data-controller="toggle-lock" to the button element
 *
 * Add data-toggle-lock-user-id-value="<%= user.id %>" to the button
 *
 * Example:
 * <button type="button"
 *         data-controller="toggle-lock"
 *         data-toggle-lock-user-id-value="<%= user.id %>"
 *         data-action="click->toggle-lock#toggle">
 *   Lock/Unlock account
 * </button>
 */
export default class extends Controller {
  static values = { 
    userId: Number
  };

  get url() {
    // Construct the URL from the user ID
    return `/users/${this.userIdValue}/toggle_lock_status`;
  }

  async toggle(event) {
    event.preventDefault();
    event.stopPropagation();

    try {
      // Use turbo-stream response kind to handle Turbo Stream responses
      await post(this.url, {
        responseKind: "turbo-stream"
      });
      // Turbo Stream will automatically update the page and show flash messages
    } catch (error) {
      console.error("Error toggling lock status:", error);
    }
  }
}
