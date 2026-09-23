import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.addEventListener("change", this.handleChange);
  }

  disconnect() {
    this.element.removeEventListener("change", this.handleChange);
  }

  handleChange = async () => {
    const clientId = this.element.value;
    const form = this.element.form;
    if (!form || !clientId) return;

    const addressUrl = `/addresses/lookup?addressable_id=${encodeURIComponent(clientId)}`;
    try {
      const response = await fetch(addressUrl);
      if (!response.ok) return;
      const data = await response.json();
      const addressTextarea = form.querySelector("[name$='[bill_to_address]'], [id$='_bill_to_address']");
      if (addressTextarea) {
        addressTextarea.value = data.address || "";
      }
    } catch {
      // Silently fail
    }
  };
}
