import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["template", "pickerContainer"];

  toggle(event) {
    const selectedType = event.target.value;

    this.pickerContainerTarget.innerHTML = "";

    const template = this.templateTargets.find(t => t.dataset.type === selectedType);
    if (template) {
      const cloned = template.content.cloneNode(true);
      this.pickerContainerTarget.appendChild(cloned);
    }
  }
}
