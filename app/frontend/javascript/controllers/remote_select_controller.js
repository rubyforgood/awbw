import { Controller } from "@hotwired/stimulus";
import TomSelect from "tom-select";

export default class extends Controller {
  static values = { model: String };

  connect() {
    this.select = new TomSelect(this.element, {
      valueField: "id",
      labelField: "label",
      searchField: "label",
      create: false,
      load: (query, callback) => {
        if (!query.length) return callback();

        fetch(`/search/${this.modelValue}?q=${encodeURIComponent(query)}`)
          .then((r) => r.json())
          .then((json) => callback(json))
          .catch(() => callback());
      },
    });
  }

  disconnect() {
    if (this.select) this.select.destroy();
  }
}
