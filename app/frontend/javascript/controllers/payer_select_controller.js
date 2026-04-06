import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["person", "organization", "payerContainer"];

  toggle(event) {
    const payerType = event.target.value;

    this.payerContainerTarget.innerHTML = "";

    if (payerType === "Person") {
      const template = this.personTarget.content.cloneNode(true);
      this.payerContainerTarget.appendChild(template);
    } else if (payerType === "Organization") {
      const template = this.organizationTarget.content.cloneNode(true);
      this.payerContainerTarget.appendChild(template);
    }
  }
}
