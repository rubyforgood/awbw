import { Controller } from "@hotwired/stimulus"
import { put } from "@rails/request.js"
import Sortable from "sortablejs"

/**
 * Sortable controller for form field editing.
 *
 * Subsection-aware: dragging a group header also moves all fields
 * that share the same subsection.
 *
 * Usage:
 *   data-controller="form-fields-sortable"
 *   data-form-fields-sortable-url-value="/forms/:id/reorder_fields"
 *
 * Each item needs:
 *   data-sortable-id="<field_id>"
 *   data-sortable-handle  (on the drag handle element)
 *   data-subsection="<subsection_name>"  (optional)
 *   data-group-header       (on header rows)
 */
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      onEnd: this.onEnd.bind(this),
      handle: "[data-sortable-handle]",
    })
  }

  disconnect() {
    this.sortable.destroy()
  }

  onEnd(event) {
    const { item } = event

    // If a group header was moved, relocate its section members to follow it
    if (item.dataset.groupHeader !== undefined) {
      const subsection = item.dataset.subsection
      const members = []

      for (const el of this.element.children) {
        if (el !== item && el.dataset.subsection === subsection && el.dataset.groupHeader === undefined) {
          members.push(el)
        }
      }

      let ref = item
      for (const member of members) {
        ref.after(member)
        ref = member
      }
    }

    // Update all positions based on current DOM order
    const items = [...this.element.children]
    const positions = []

    items.forEach((el, index) => {
      const pos = index + 1
      positions.push({ id: parseInt(el.dataset.sortableId), position: pos })

      // Update hidden position field so form submit stays in sync
      const posInput = el.querySelector("input[name*='[position]']")
      if (posInput) posInput.value = pos
    })

    put(this.urlValue, {
      body: JSON.stringify({ positions }),
    })
  }
}
