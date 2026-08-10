import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="subject-select"
//
// Fills the contact form's subject line from a preset picker — used on the
// Story Share portal variant so visitors self-route to the right team.
export default class extends Controller {
  static targets = ["subject"];

  populate(event) {
    this.subjectTarget.value = event.target.value;
  }
}
