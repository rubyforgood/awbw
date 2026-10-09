import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.css";

export default class extends Controller {
  static targets = ["select"];

  connect() {
    if (!this.hasSelectTarget) return;

    this.selectTargets.forEach((select) => {
      if (select._tomSelect) return;

      // The form's collection controller submits on the native change TomSelect dispatches on the select.
      select._tomSelect = new TomSelect(select, {
        plugins: ["checkbox_options", "remove_button"],
        onInitialize() {
          this.control.classList.add("!rounded-lg", "!py-2");
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
