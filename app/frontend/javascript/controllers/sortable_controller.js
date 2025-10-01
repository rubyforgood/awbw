import { Controller } from "@hotwired/stimulus";
import { put } from "@rails/request.js";
import Sortable from "sortablejs";
export default class extends Controller {
  static values = { url: String };

  connect() {
    this.sortable = Sortable.create(this.element, {
      onEnd: this.onEnd.bind(this),
      handle: "[data-sortable-handle]",
    });
  }

  disconnect() {
    this.sortable.destroy();
  }

  onEnd(event) {
    const { newIndex, item } = event;
    const id = item.dataset["sortable-id"];
    const url = this.urlValue.replace("ordering", id);
    put(url, {
      body: JSON.stringify({ ordering: newIndex }),
    });
  }
}
