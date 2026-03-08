import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.css";

export default class extends Controller {
  connect() {
    if (this.element._tomSelect) return;

    this.element._tomSelect = new TomSelect(this.element, {
      plugins: ["dropdown_input", "checkbox_options", "remove_button"],
      create: false,
      onChange: () => {
        this.element.closest("form")?.requestSubmit();
      },
    });
  }

  disconnect() {
    if (this.element._tomSelect) {
      this.element._tomSelect.destroy();
      this.element._tomSelect = null;
    }
  }
}
