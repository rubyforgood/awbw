import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["template", "pickerContainer"];

  connect() {
    this._placeholder = this.pickerContainerTarget.innerHTML;

    // A type already selected on load (prefilled, or kept from the URL) shows its
    // picker right away instead of waiting for a change.
    const typeSelect = this.element.querySelector('[data-action~="search-type-select#toggle"]');
    if (typeSelect?.value) this.toggle({ target: typeSelect });
  }

  toggle(event) {
    const selectedType = event.target.value;

    this.pickerContainerTarget.innerHTML = "";

    if (!selectedType) {
      this.pickerContainerTarget.innerHTML = this._placeholder;
      return;
    }

    const template = this.templateTargets.find(t => t.dataset.type === selectedType);
    if (template) {
      const cloned = template.content.cloneNode(true);
      this.pickerContainerTarget.appendChild(cloned);
    }
  }
}
