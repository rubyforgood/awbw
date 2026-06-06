import { Controller } from "@hotwired/stimulus";

// Handles filtering/searching the question library picker on the forms edit page.
export default class extends Controller {
  static targets = ["search", "list", "item"];

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim();

    this.itemTargets.forEach((item) => {
      const text = item.dataset.questionText || "";
      item.style.display = text.includes(query) ? "" : "none";
    });
  }
}
