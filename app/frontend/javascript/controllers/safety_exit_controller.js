import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="safety-exit"
// Quick-escape for visitors who need to leave the site instantly (e.g. domestic
// violence survivors). Opens a neutral site in a new tab and replaces the
// current page so the back button doesn't return here. Note: this cannot scrub
// the full browser history — a known limitation of client-side safety exits.
export default class extends Controller {
  leave() {
    window.open("https://www.google.com", "_blank")
    window.location.replace("https://www.weather.com")
  }
}
