import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="navigate-select"
//
// Navigates to a per-record page when a picker's selection changes — pairs with
// remote-select for "search a record, jump to its page" controls (e.g. jumping
// from one person's comments page to another's). The destination comes from
// urlTemplate with "__ID__" replaced by the selected value.
export default class extends Controller {
  static values = { urlTemplate: String };

  navigate(event) {
    const id = event.target.value;
    if (id) window.location.href = this.urlTemplateValue.replace("__ID__", id);
  }
}
