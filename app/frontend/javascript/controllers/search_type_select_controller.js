import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["person", "organization", "pickerContainer"];

  toggle(event) {
    const selectedType = event.target.value;

    this.pickerContainerTarget.innerHTML = "";

    if (selectedType === "Person") {
      const template = this.personTarget.content.cloneNode(true);
      this.pickerContainerTarget.appendChild(template);
    } else if (selectedType === "Organization") {
      const template = this.organizationTarget.content.cloneNode(true);
      this.pickerContainerTarget.appendChild(template);
    }
  }
}
