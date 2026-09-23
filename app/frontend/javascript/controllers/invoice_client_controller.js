import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["billToAddress", "clientSelect"]

  connect() {
    this.clientSelectTarget.addEventListener("change", this.handleChange);
  }

  disconnect() {
    this.clientSelectTarget.removeEventListener("change", this.handleChange);
  }

  handleChange = async () => {
    const clientSgid = this.clientSelectTarget.value;
    if (!clientSgid) return;

    const addressUrl = `/addresses/lookup?addressable_sgid=${encodeURIComponent(clientSgid)}`;
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
