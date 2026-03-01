import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "select", "item"];

  addItem() {
    const select = this.selectTarget;
    const tomSelect = select.tomselect;
    const id = tomSelect ? tomSelect.getValue() : select.value;
    const label = tomSelect
      ? tomSelect.getItem(id)?.textContent
      : select.options[select.selectedIndex]?.text;

    if (!id) return;

    // Prevent duplicates
    const existing = this.listTarget.querySelector(
      `input[value="${id}"]`
    );
    if (existing) return;

    const item = document.createElement("div");
    item.className = `inline-flex items-center gap-2
      rounded-md border border-gray-300 hover:border-gray-400
      bg-blue-50 hover:bg-blue-200
      text-gray-700 px-3 py-1 text-sm font-medium transition`;
    item.setAttribute("data-payment-registrations-target", "item");
    item.innerHTML = `
      <input type="hidden" name="payment[event_registration_ids][]" value="${id}">
      <span>${label}</span>
      <button type="button"
              class="ml-1.5 text-gray-400 hover:text-gray-600 font-bold text-xs transition"
              data-action="click->payment-registrations#removeItem">✖</button>
    `;

    this.listTarget.appendChild(item);

    // Clear the select
    if (tomSelect) {
      tomSelect.clear();
    } else {
      select.value = "";
    }
  }

  removeItem(event) {
    event.currentTarget.closest("[data-payment-registrations-target='item']").remove();
  }
}
