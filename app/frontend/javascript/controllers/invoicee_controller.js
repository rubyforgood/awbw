import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["invoiceeSelect", "addressContainer", "addressSelect"];

  connect() {
    this.invoiceeSelectTarget.addEventListener("change", this.loadAddresses);
    if (this.invoiceeSelectTarget.value) this.loadAddresses();
  }

  disconnect() {
    this.invoiceeSelectTarget.removeEventListener("change", this.loadAddresses);
  }

  loadAddresses = async () => {
    const invoiceeSgid = this.invoiceeSelectTarget.value;
    if (!invoiceeSgid) {
      this.clearAddresses();
      return;
    }

    const addressUrl = `/addresses/options?addressable_sgid=${encodeURIComponent(invoiceeSgid)}`;
    try {
      const response = await fetch(addressUrl);
      if (!response.ok) {
        this.clearAddresses();
        return;
      }
      const data = await response.json();
      this.renderAddresses(data.addresses || []);
    } catch {
      this.clearAddresses();
    }
  };

  renderAddresses(addresses) {
    // Repopulating must not drop the saved address.
    const selected = this.addressSelectTarget.value;

    this.addressSelectTarget.replaceChildren(
      new Option("No address", ""),
      ...addresses.map(({ id, label }) => new Option(label, id))
    );

    this.addressSelectTarget.value = selected;
    this.addressContainerTarget.classList.toggle("hidden", addresses.length === 0);
  }

  clearAddresses() {
    this.addressSelectTarget.replaceChildren(new Option("No address", ""));
    this.addressSelectTarget.value = "";
    this.addressContainerTarget.classList.add("hidden");
  }
}
