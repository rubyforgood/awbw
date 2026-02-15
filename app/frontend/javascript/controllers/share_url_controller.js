import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="share-url"
export default class extends Controller {

  static targets = ["form", "output"]

  copy(event) {
    event.preventDefault();

    // Build URL from form data
    const form = this.element;
    const formData = new FormData(form);
    const params = new URLSearchParams();
    
    // Manually add each form field to URLSearchParams for Safari compatibility
    for (const [key, value] of formData.entries()) {
      // Include all values except empty strings to keep URLs clean
      if (value !== '') {
        params.append(key, value);
      }
    }
    
    const shareUrl = `${form.action}?${params.toString()}`;

   this.outputTarget.value = shareUrl;
   this.outputTarget.classList.remove("hidden");
    
    navigator.clipboard.writeText(shareUrl).then(() => {
      alert("Search URL copied to clipboard!");
    });
  }
}
