import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["template", "pickerContainer"];

  connect() {
    this._placeholder = this.pickerContainerTarget.innerHTML;
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
