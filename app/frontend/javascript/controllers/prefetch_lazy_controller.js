// https://radanskoric.com/articles/load-lazy-loaded-frame-before-it-scrolls-in-view
import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="prefetch-lazy"
export default class extends Controller {
  connect() {
    if (this.element.getAttribute("loading") == "lazy") {
      this.observer = new IntersectionObserver(this.intersect, {
        // set how far below the viewport the lazy loading is triggered
        rootMargin: "0px 0px 500px 0px",
      });
      this.observer.observe(this.element);
    }
  }

  disconnect() {
    this.observer?.disconnect();
  }

  intersect = (entries) => {
    const lastEntry = entries.slice(-1)[0];
    if (lastEntry?.isIntersecting) {
      this.observer.unobserve(this.element); // We only need to do this once
      this.element.setAttribute("loading", "eager");
    }
  };
}
