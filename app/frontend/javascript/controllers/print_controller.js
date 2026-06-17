import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="print"
// Opens the browser's print dialog so the page can be saved as a PDF.
export default class extends Controller {
  print() {
    window.print();
  }
}
