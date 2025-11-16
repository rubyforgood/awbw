import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="share-url"
export default class extends Controller {

  static targets = ["form", "output"]

  copy(event) {
    event.preventDefault();

    // Build URL from form data
    const form = this.element;
    const params = new URLSearchParams(new FormData(form)).toString();
    const shareUrl = `${form.action}?${params}`;

   this.outputTarget.value = shareUrl;
   this.outputTarget.classList.remove("hidden")
    
    navigator.clipboard.writeText(shareUrl).then(() => {
      alert("Search URL copied to clipboard!");
    });
  }
}
