import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["billToAddress", "invoiceeSelect"]

  connect() {
    this.invoiceeSelectTarget.addEventListener("change", this.handleChange);
  }

  disconnect() {
    this.invoiceeSelectTarget.removeEventListener("change", this.handleChange);
  }

  handleChange = async () => {
    const invoiceeSgid = this.invoiceeSelectTarget.value;
    if (!invoiceeSgid) return;

    const addressUrl = `/addresses/lookup?addressable_sgid=${encodeURIComponent(invoiceeSgid)}`;
    try {
      const response = await fetch(addressUrl);
      if (!response.ok) return;
      const data = await response.json();
      this.billToAddressTarget.value = data.address || "";
    } catch {
      // Silently fail
    }
  };
}
