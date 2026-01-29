import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="optimistic-bookmark"
export default class extends Controller {
  static targets = ["icon", "text"];

  toggle(event) {
    this.iconTarget.classList.toggle("far");
    this.iconTarget.classList.toggle("fas");

    if (this.textTarget.textContent === "Bookmark") {
      this.textTarget.textContent = "Bookmarked";
    } else {
      this.textTarget.textContent = "Bookmark";
    }
  }
}
