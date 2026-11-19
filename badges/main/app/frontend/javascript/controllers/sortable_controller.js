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
 * Only children carrying data-sortable-id are draggable and counted, so
 * non-item siblings (e.g. the hidden id inputs `fields_for` emits after each
 * nested record) don't inflate the position sent to the server.
 *
 */
export default class extends Controller {
  static values = { url: String };

  connect() {
    this.sortable = Sortable.create(this.element, {
      onEnd: this.onEnd.bind(this),
      handle: "[data-sortable-handle]",
      draggable: ">[data-sortable-id]",
    });
  }

  disconnect() {
    this.sortable.destroy();
  }

  onEnd(event) {
    const { newDraggableIndex, oldDraggableIndex, item } = event;
    if (newDraggableIndex === oldDraggableIndex) return;
    const id = item.dataset.sortableId;
    const url = this.urlValue.replace(":id", id);
    put(url, {
      body: JSON.stringify({ position: newDraggableIndex + 1 }), // add 1 to change sortablejs 0-based index to 1-based for positioning gem
    });
  }
}
