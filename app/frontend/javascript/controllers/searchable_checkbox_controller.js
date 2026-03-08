import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.css";

export default class extends Controller {
  static targets = ["select"];

  connect() {
    if (!this.hasSelectTarget) return;

    this.selectTargets.forEach((select) => {
      if (select._tomSelect) return;

      select._tomSelect = new TomSelect(select, {
        plugins: ["dropdown_input", "checkbox_options", "remove_button"],
        create: false,
        onChange: () => {
          this.element.requestSubmit();
        },
      });
    });
  }

  disconnect() {
    this.selectTargets.forEach((select) => {
      if (select._tomSelect) {
        select._tomSelect.destroy();
        select._tomSelect = null;
      }
    });
  }
}
