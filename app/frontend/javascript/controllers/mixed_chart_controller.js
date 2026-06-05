import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

// Connects to data-controller="mixed-chart"
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    userVisits: Object,
    publicVisits: Object,
    logins: Object
  }

  connect() {
    const labels = [...new Set([
      ...Object.keys(this.userVisitsValue),
      ...Object.keys(this.publicVisitsValue),
      ...Object.keys(this.loginsValue)
    ])].sort()

    const formatLabel = (dateStr) => {
      const d = new Date(dateStr)
      return d.toLocaleDateString("en-US", { month: "short", day: "numeric" })
    }

    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels: labels.map(formatLabel),
        datasets: [
          {
            label: "User visits",
            data: labels.map(l => this.userVisitsValue[l] || 0),
            backgroundColor: "rgba(59, 130, 246, 0.6)",
            stack: "visits",
            order: 2
          },
          {
            label: "Public visits",
            data: labels.map(l => this.publicVisitsValue[l] || 0),
            backgroundColor: "rgba(156, 163, 175, 0.5)",
            stack: "visits",
            order: 2
          },
          {
            type: "line",
            label: "Logins",
            data: labels.map(l => this.loginsValue[l] || 0),
            borderColor: "rgba(239, 68, 68, 0.8)",
            backgroundColor: "transparent",
            borderWidth: 2,
            pointRadius: 3,
            order: 1
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: { stacked: true },
          y: { beginAtZero: true }
        },
        plugins: {
          legend: { position: "top" }
        }
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}
