import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabLink", "tabContent"]

  connect() {
    // Hide all tab contents except the first one
    this.tabContentTargets.forEach((c, i) => {
      c.classList.toggle("hidden", i !== 0)
    })
    // Make the first tab link active
    this.tabLinkTargets.forEach((l, i) => {
      l.classList.toggle("is-active", i === 0)
    })
  }

  switch(event) {
    event.preventDefault()
    const index = this.tabLinkTargets.indexOf(event.currentTarget)
    if (index === -1) return

    // Remove active class from all links
    this.tabLinkTargets.forEach(l => l.classList.remove("is-active"))
    // Hide all tab contents
    this.tabContentTargets.forEach(c => c.classList.add("hidden"))

    // Activate clicked tab
    event.currentTarget.classList.add("is-active")
    if (this.tabContentTargets[index]) {
      this.tabContentTargets[index].classList.remove("hidden")
    }
  }
}
