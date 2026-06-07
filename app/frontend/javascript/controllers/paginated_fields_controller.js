import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item", "nav"];
  static values = { perPage: { type: Number, default: 10 } };

  connect() {
    this.currentPage = 1;
    this.render();
    this.ready = true;
  }

  get visibleItems() {
    return this.itemTargets.filter(
      (el) => !el.style.display || el.style.display !== "none"
    );
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.visibleItems.length / this.perPageValue));
  }

  next() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.render();
    }
  }

  previous() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.render();
    }
  }

  render() {
    const items = this.visibleItems;
    const start = (this.currentPage - 1) * this.perPageValue;
    const end = start + this.perPageValue;

    items.forEach((el, i) => {
      el.classList.toggle("hidden", i < start || i >= end);
    });

    if (this.currentPage > this.totalPages) {
      this.currentPage = this.totalPages;
      this.render();
      return;
    }

    this.renderNav();
  }

  renderNav() {
    if (!this.hasNavTarget) return;

    if (this.totalPages <= 1) {
      this.navTarget.classList.add("hidden");
      return;
    }

    this.navTarget.classList.remove("hidden");
    this.navTarget.innerHTML = `
      <div class="flex items-center justify-center gap-3 mt-4">
        <button type="button" data-action="paginated-fields#previous"
                class="px-3 py-1 border border-gray-200 rounded-md bg-white text-gray-500 hover:bg-gray-100 ${this.currentPage <= 1 ? 'opacity-30 cursor-default' : ''}"
                ${this.currentPage <= 1 ? 'disabled' : ''}>
          &laquo;
        </button>
        <span class="text-sm text-gray-600">
          ${this.currentPage} / ${this.totalPages}
        </span>
        <button type="button" data-action="paginated-fields#next"
                class="px-3 py-1 border border-gray-200 rounded-md bg-white text-gray-500 hover:bg-gray-100 ${this.currentPage >= this.totalPages ? 'opacity-30 cursor-default' : ''}"
                ${this.currentPage >= this.totalPages ? 'disabled' : ''}>
          &raquo;
        </button>
      </div>
    `;
  }

  // Re-render when items are added/removed (cocoon). On a user-triggered add
  // (after the initial render), jump to the page holding the new item — which is
  // appended last — so it's visible instead of being hidden on a later page.
  itemTargetConnected() {
    if (!this.ready) return;
    this.currentPage = this.totalPages;
    this.render();
  }

  itemTargetDisconnected() {
    if (!this.ready) return;
    this.render();
  }
}
