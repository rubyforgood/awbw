// Connects to data-controller="lexxy-youtube"
import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  static values = {
    url: String // Rails controller endpoint 
  }

  // Called automatically when a link is pasted in Lexxy
  unfurl(event) {
    this.#unfurlLink(event.detail.url, event.detail)
  }

async #unfurlLink(url, callbacks) {
  try {
    const { response } = await post(this.urlValue, {
      body: JSON.stringify({ url }),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      }
    })

    // Parse JSON from response
    const metadata = await response.json()

    // Insert below the link
    callbacks.insertBelowLink(this.#renderUnfurledHTML(metadata), {
      attachment: { sgid: metadata.sgid }
    })
  } catch (err) {
    console.error("Error unfurling YouTube URL:", err)
  }
}

  #renderUnfurledHTML(link) {
    console.log(link)
    // Example: show thumbnail + title linking to YouTube
    return `
      <div class="lexxy-youtube-embed" style="display:flex; align-items:center; gap:0.5rem; margin:0.5rem 0;">
        <img src="${link.thumbnail_url}" alt="${link.title}" style="width:120px; height:auto; border-radius:4px;">
        <a href="${link.canonical_url}" target="_blank" rel="noopener noreferrer">${link.title}</a>
      </div>
    `
  }
}
