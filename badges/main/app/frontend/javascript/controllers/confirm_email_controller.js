import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

/*
 * Usage
 * =====
 *
 * Add data-controller="confirm-email" to the button element
 *
 * Add data-confirm-email-user-id-value="<%= user.id %>" to the button
 *
 * Example:
 * <button type="button"
 *         data-controller="confirm-email"
 *         data-confirm-email-user-id-value="<%= user.id %>"
 *         data-action="click->confirm-email#confirm">
 *   Manually confirm email
 * </button>
 */
export default class extends Controller {
  static values = { 
    userId: Number
  };

  get url() {
    // Construct the URL from the user ID
    return `/users/${this.userIdValue}/confirm_email`;
  }

  async confirm(event) {
    event.preventDefault();
    event.stopPropagation();

    try {
      // Use turbo-stream response kind to handle Turbo Stream responses
      await post(this.url, {
        responseKind: "turbo-stream"
      });
      // Turbo Stream will automatically update the page and show flash messages
    } catch (error) {
      console.error("Error confirming email:", error);
    }
  }
}
