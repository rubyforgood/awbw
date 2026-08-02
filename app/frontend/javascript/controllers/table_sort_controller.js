import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table-sort"
// Click a column header button (data-table-sort-target="header" with a
// data-sort-index) to sort the rows in the tbody (data-table-sort-target="body").
// Cells expose their sort key via data-sort-value, falling back to text content.
// A header may also set data-sort-key="foo" to read a named key from the cell
// (data-sort-foo) instead — letting one cell offer several sub-sorts (e.g. a
// Name cell sortable by first or last name).
// Numeric values sort numerically; everything else sorts alphabetically.
// Every sort starts from the server's initial row order (see connect), and
// Array#sort is stable, so equal values keep that order — i.e. the server's
// default ordering (e.g. by name) is the secondary sort, for free.
// Each header's indicator is a Font Awesome icon: fa-sort (neutral up/down
// carets) by default, fa-sort-up / fa-sort-down on the active sort.
export default class extends Controller {
  static targets = ["body", "header"]

  connect() {
    // The server-rendered order — reused as the base for every sort so ties break
    // by it (a stable sort) rather than by whatever the previous sort left behind.
    this.initialRows = Array.from(this.bodyTarget.rows)
  }

  sort(event) {
    const header = event.currentTarget
    const index = Number(header.dataset.sortIndex)
    const key = header.dataset.sortKey
    const ascending = header.dataset.sortDirection !== "asc"

    const rows = [ ...this.initialRows ]
    rows.sort((a, b) => this.compare(a, b, index, key) * (ascending ? 1 : -1))
    rows.forEach((row) => this.bodyTarget.appendChild(row))

    this.headerTargets.forEach((other) => {
      delete other.dataset.sortDirection
      other.closest("th")?.setAttribute("aria-sort", "none")
      this.setIndicator(other, "neutral")
    })

    header.dataset.sortDirection = ascending ? "asc" : "desc"
    header.closest("th")?.setAttribute("aria-sort", ascending ? "ascending" : "descending")
    this.setIndicator(header, ascending ? "asc" : "desc")
  }

  setIndicator(header, state) {
    const icon = this.indicatorFor(header)?.querySelector("i")
    if (!icon) return
    icon.classList.remove("fa-sort", "fa-sort-up", "fa-sort-down", "text-gray-700", "text-gray-400")
    const direction = state === "asc" ? "fa-sort-up" : state === "desc" ? "fa-sort-down" : "fa-sort"
    icon.classList.add(direction, state === "neutral" ? "text-gray-400" : "text-gray-700")
  }

  compare(rowA, rowB, index, key) {
    const a = this.cellValue(rowA, index, key)
    const b = this.cellValue(rowB, index, key)
    // Strict Number(), not parseFloat(): parseFloat("2026-12-31") is 2026, which
    // would collapse every date in a year to one value and leave date columns
    // effectively unsorted. Number() rejects such strings (NaN) so ISO dates fall
    // through to localeCompare, which orders them correctly since they're padded.
    const numA = a === "" ? NaN : Number(a)
    const numB = b === "" ? NaN : Number(b)
    if (!isNaN(numA) && !isNaN(numB)) return numA - numB
    return a.localeCompare(b)
  }

  cellValue(row, index, key) {
    const cell = row.cells[index]
    if (!cell) return ""
    const named = key ? cell.dataset[`sort${key.charAt(0).toUpperCase()}${key.slice(1)}`] : undefined
    return (named ?? cell.dataset.sortValue ?? cell.textContent ?? "").trim().toLowerCase()
  }

  indicatorFor(header) {
    return header.querySelector("[data-sort-indicator]")
  }
}
