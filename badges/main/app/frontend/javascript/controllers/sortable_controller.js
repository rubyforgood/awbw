import { Controller } from "@hotwired/stimulus";
import { put } from "@rails/request.js";
import Sortable from "sortablejs";

/*
 * Usage
 * =====
 *
 * add data-controller="sortable" to common ancestor
 *
 * 1. Add data-sortable-url-value="URL to update position" to the
 * controller container
 *
 * 2. Add data-sortable-handle to the drag handle:
 *
 * 3. Add data-sortable-id to the item
 *
 */
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
    const id = item.dataset.sortableId;
    const url = this.urlValue.replace(":id", id);
    put(url, {
      body: JSON.stringify({ ordering: newIndex + 1 }), // add 1 to change sortablejs 0-based index to 1-based for positioning gem
    });
  }
}
