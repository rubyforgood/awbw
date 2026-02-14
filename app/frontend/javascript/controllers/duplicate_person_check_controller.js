import { Controller } from "@hotwired/stimulus";
import { post } from "@rails/request.js";

/*
 * Usage
 * =====
 *
 * Add data-controller="duplicate-person-check" to the form element
 *
 * Add data-duplicate-person-check-target="firstName" to the first name input
 * Add data-duplicate-person-check-target="lastName" to the last name input  
 * Add data-duplicate-person-check-target="email" to the email input
 * Add data-duplicate-person-check-target="modal" to the confirmation modal
 * Add data-duplicate-person-check-target="duplicatesList" to the duplicates list container
 * Add data-duplicate-person-check-target="proceedButton" to the proceed anyway button
 * Add data-duplicate-person-check-target="cancelButton" to the cancel button
 *
 * Add data-action="submit->duplicate-person-check#checkBeforeSubmit" to the form
 *
 * Example:
 * <form data-controller="duplicate-person-check"
 *       data-action="submit->duplicate-person-check#checkBeforeSubmit">
 *   <input type="text" data-duplicate-person-check-target="firstName" />
 *   <input type="text" data-duplicate-person-check-target="lastName" />
 *   <input type="email" data-duplicate-person-check-target="email" />
 * </form>
 */
export default class extends Controller {
  static targets = [
    "firstName",
    "lastName", 
    "email",
    "modal",
    "duplicatesList",
    "proceedButton",
    "cancelButton"
  ];

  connect() {
    this.shouldProceed = false;
  }

  async checkBeforeSubmit(event) {
    // If we've already confirmed to proceed, allow submission
    if (this.shouldProceed) {
      return true;
    }

    // Only check for new person records (not edits)
    const personIdField = this.element.querySelector('input[name*="[id]"]');
    if (personIdField && personIdField.value) {
      return true;
    }

    event.preventDefault();
    event.stopPropagation();

    const firstName = this.hasFirstNameTarget ? this.firstNameTarget.value : "";
    const lastName = this.hasLastNameTarget ? this.lastNameTarget.value : "";
    const email = this.hasEmailTarget ? this.emailTarget.value : "";

    // Only check if we have name or email
    if (!firstName && !lastName && !email) {
      this.element.submit();
      return;
    }

    try {
      const response = await post("/people/check_duplicates", {
        body: JSON.stringify({
          first_name: firstName,
          last_name: lastName,
          email: email
        }),
        contentType: "application/json",
        responseKind: "json"
      });

      if (response.ok) {
        const data = await response.json;
        
        if (data.duplicates && data.duplicates.length > 0) {
          this.showDuplicatesModal(data.duplicates);
        } else {
          // No duplicates, proceed with submission
          this.shouldProceed = true;
          this.element.submit();
        }
      }
    } catch (error) {
      console.error("Error checking for duplicates:", error);
      // On error, proceed with submission to avoid blocking the user
      this.shouldProceed = true;
      this.element.submit();
    }
  }

  showDuplicatesModal(duplicates) {
    if (!this.hasModalTarget) {
      console.warn("Modal target not found, proceeding anyway");
      this.shouldProceed = true;
      this.element.submit();
      return;
    }

    // Populate the duplicates list
    if (this.hasDuplicatesListTarget) {
      this.duplicatesListTarget.innerHTML = duplicates.map(dup => {
        const email = dup.email ? ` (${dup.email})` : "";
        return `<li class="py-2 border-b border-gray-200">
          <a href="/people/${dup.id}" target="_blank" class="text-blue-600 hover:text-blue-800 underline">
            ${this.escapeHtml(dup.name)}${this.escapeHtml(email)}
          </a>
        </li>`;
      }).join("");
    }

    // Show the modal
    this.modalTarget.classList.remove("hidden");
  }

  proceedAnyway(event) {
    event.preventDefault();
    this.shouldProceed = true;
    this.hideModal();
    this.element.submit();
  }

  cancel(event) {
    event.preventDefault();
    this.shouldProceed = false;
    this.hideModal();
  }

  hideModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden");
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
