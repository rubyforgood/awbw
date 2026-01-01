// app/javascript/controllers/print_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    trackAndPrint(event) {
        console.log("PRINT CLICKED")
        window.print()
        event.preventDefault()

        fetch("/admin/analytics/print", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
            },
            body: JSON.stringify({
                printable_type: this.element.dataset.printableType,
                printable_id: this.element.dataset.printableId
            })
        }).finally(() => {
            window.print()
        })
    }
}
