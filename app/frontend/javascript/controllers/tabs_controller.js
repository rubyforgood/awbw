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

    showTab(link) {
        // Remove active class from all links
        this.tabLinkTargets.forEach(l => l.classList.remove("is-active"))
        // Hide all tab contents
        this.tabContentTargets.forEach(c => c.classList.add("hidden"))

        // Add active class to clicked link
        link.classList.add("is-active")

        // Show the corresponding content
        const contentId = link.dataset.tabContentId
        if (!contentId) return
        const content = document.getElementById(contentId)
        if (content) content.classList.remove("hidden")
    }

    switch(event) {
        event.preventDefault()
        this.showTab(event.currentTarget)
    }
}
