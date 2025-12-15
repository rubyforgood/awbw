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

    callbacks.replaceLinkWith(this.#renderUnfurledHTML(metadata), {
      attachment: { sgid: metadata.sgid }
    })
  } catch (err) {
    console.error("Error unfurling YouTube URL:", err)
  }
}

  #renderUnfurledHTML(link) {
    let siParam = '';
    try {
      const urlParams = new URL(link.canonical_url).searchParams;
      siParam = urlParams.get('si') || '';
    } catch (e) {
      // ignore if URL parsing fails
    }
    return `
      <iframe
        width="560"
        height="315"
        src="https://www.youtube.com/embed/${link.video_id}?si=${siParam}"
        title="${link.title}"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        referrerpolicy="strict-origin-when-cross-origin"
        allowfullscreen
        style="border-radius:4px;"
      ></iframe>
    `
  }
}
