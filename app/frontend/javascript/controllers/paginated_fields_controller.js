import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item", "nav"];
  static values = {
    perPage: { type: Number, default: 10 },
    grouped: { type: Boolean, default: false },
    noSubjectLabel: { type: String, default: "No subject" }
  };

  connect() {
    this.currentPage = 1;
    this.groupHeaders = [];
    this.render();
    this.ready = true;
    this.revealHashTarget();
  }

  // When the page loads with a #fragment matching a row inside this controller
  // (e.g. returning from the affiliation editor to its row), jump to the page
  // holding that row — otherwise it's hidden on a later page — and scroll to it.
  revealHashTarget() {
    if (this.groupedValue) return;
    const hash = window.location.hash;
    if (hash.length < 2) return;

    const id = hash.slice(1);
    const items = this.visibleItems;
    const index = items.findIndex(
      (el) => el.id === id || el.querySelector(`#${CSS.escape(id)}`)
    );
    if (index === -1) return;

    this.currentPage = Math.floor(index / this.perPageValue) + 1;
    this.render();

    const target = document.getElementById(id) || items[index];
    requestAnimationFrame(() => target.scrollIntoView({ block: "center" }));
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
      <div class="mt-4 flex items-center justify-center gap-3">
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

  // Flip between the flat, paginated list and one clustered by subject line.
  toggleGrouping(event) {
    this.groupedValue = event.target.checked;
  }

  groupedValueChanged() {
    if (!this.ready) return;
    if (this.groupedValue) {
      this.renderGrouped();
    } else {
      this.restoreFlat();
    }
  }

  // Cluster the rows by subject line, newest group first (a group's position is
  // its newest row's, and rows are already newest-first). Rows are reordered with
  // the CSS `order` property so their DOM position never changes — moving nodes
  // would churn Stimulus's target callbacks. Every row is shown; the flat pager
  // steps aside while grouped.
  renderGrouped() {
    const parent = this.listElement;
    if (!parent) return;

    this.clearGroupHeaders();
    const groups = new Map();
    for (const el of this.itemTargets) {
      const key = this.subjectKey(el);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(el);
    }

    // Newest row first within each group, and groups by their newest row.
    const ordered = [...groups.values()]
      .map((rows) => rows.sort((a, b) => this.itemDate(b) - this.itemDate(a)))
      .sort((a, b) => this.itemDate(b[0]) - this.itemDate(a[0]));

    let order = 1;
    for (const rows of ordered) {
      const header = this.buildHeader(rows[0], rows.length);
      header.style.order = order++;
      parent.appendChild(header);
      this.groupHeaders.push(header);
      for (const el of rows) {
        el.classList.remove("hidden");
        el.style.order = order++;
      }
    }

    if (this.hasNavTarget) this.navTarget.classList.add("hidden");
  }

  restoreFlat() {
    this.clearGroupHeaders();
    this.itemTargets.forEach((el) => (el.style.order = ""));
    this.currentPage = 1;
    this.render();
  }

  subjectKey(el) {
    return (el.dataset.subject || "").trim().toLowerCase();
  }

  itemDate(el) {
    return Number(el.dataset.createdAt) || 0;
  }

  buildHeader(firstRow, count) {
    const header = document.createElement("div");
    header.dataset.groupHeader = "true";
    header.className =
      "mt-3 mb-1 flex items-center gap-2 border-b border-gray-100 pb-1 first:mt-0";
    const subject = (firstRow.dataset.subject || "").trim() || this.noSubjectLabelValue;
    header.innerHTML = `
      <i class="fa-solid fa-layer-group text-2xs text-gray-400" aria-hidden="true"></i>
      <span class="text-xs font-semibold text-gray-600"></span>
      <span class="text-2xs text-gray-400"></span>
    `;
    header.querySelector("span").textContent = subject;
    header.querySelectorAll("span")[1].textContent = `${count} ${count === 1 ? "item" : "items"}`;
    return header;
  }

  clearGroupHeaders() {
    this.groupHeaders.forEach((el) => el.remove());
    this.groupHeaders = [];
  }

  get listElement() {
    return this.itemTargets[0]?.parentElement;
  }

  // Re-render when items are added/removed (cocoon). On a user-triggered add
  // (after the initial render), jump to the page holding the new item — which is
  // appended last — so it's visible instead of being hidden on a later page.
  itemTargetConnected() {
    if (!this.ready) return;
    if (this.groupedValue) {
      this.renderGrouped();
      return;
    }
    this.currentPage = this.totalPages;
    this.render();
  }

  itemTargetDisconnected() {
    if (!this.ready) return;
    if (this.groupedValue) {
      this.renderGrouped();
      return;
    }
    this.render();
  }
}
