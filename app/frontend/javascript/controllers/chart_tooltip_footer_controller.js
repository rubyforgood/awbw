import { Controller } from "@hotwired/stimulus"
import Chartkick from "chartkick"

// Connects to data-controller="chart-tooltip-footer"
// Appends footer lines to a chartkick stacked tooltip: an optional summed
// "Total" of the visible stack, plus optional pre-formatted lines keyed by the
// hovered x-label. Needed because chartkick serialises options to JSON, so a
// Chart.js callback function can't be passed through the ERB helper — we grab
// the rendered chart by id and set the callback here.
export default class extends Controller {
  static values = {
    chartId: String,
    prefix: { type: String, default: "" },
    total: { type: Boolean, default: false },
    totalLabel: { type: String, default: "Total" },
    lines: { type: Object, default: {} }
  }

  connect() {
    this.apply()
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  // chartkick renders asynchronously, so retry briefly until the chart exists.
  apply(attempt = 0) {
    const chart = Chartkick.charts?.[this.chartIdValue]
    const chartObject = chart?.getChartObject?.()
    if (!chartObject) {
      if (attempt < 20) this.timer = setTimeout(() => this.apply(attempt + 1), 50)
      return
    }

    const plugins = (chartObject.options.plugins ||= {})
    const tooltip = (plugins.tooltip ||= {})
    const callbacks = (tooltip.callbacks ||= {})
    callbacks.footer = (items) => this.footer(items)
    chartObject.update()
  }

  footer(items) {
    const footerLines = []
    if (this.totalValue) {
      const total = items.reduce((sum, item) => sum + (item.parsed?.y || 0), 0)
      footerLines.push(`${this.totalLabelValue}: ${this.prefixValue}${total.toLocaleString()}`)
    }
    const extra = this.linesValue[items[0]?.label]
    if (extra) footerLines.push(...extra)
    return footerLines
  }
}
