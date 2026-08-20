import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"
import { rampTo } from "../lib/color_ramp"

// US state / territory name → USPS abbreviation, so the choropleth can match the
// dashboard's abbreviation-keyed counts (e.g. { "CA": 5 }) to us-atlas features,
// whose properties.name is the full state name (e.g. "California").
const abbrByStateName = {
  Alabama: "AL", Alaska: "AK", Arizona: "AZ", Arkansas: "AR", California: "CA",
  Colorado: "CO", Connecticut: "CT", Delaware: "DE", "District of Columbia": "DC",
  Florida: "FL", Georgia: "GA", Hawaii: "HI", Idaho: "ID", Illinois: "IL",
  Indiana: "IN", Iowa: "IA", Kansas: "KS", Kentucky: "KY", Louisiana: "LA",
  Maine: "ME", Maryland: "MD", Massachusetts: "MA", Michigan: "MI", Minnesota: "MN",
  Mississippi: "MS", Missouri: "MO", Montana: "MT", Nebraska: "NE", Nevada: "NV",
  "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
  "North Carolina": "NC", "North Dakota": "ND", Ohio: "OH", Oklahoma: "OK",
  Oregon: "OR", Pennsylvania: "PA", "Rhode Island": "RI", "South Carolina": "SC",
  "South Dakota": "SD", Tennessee: "TN", Texas: "TX", Utah: "UT", Vermont: "VT",
  Virginia: "VA", Washington: "WA", "West Virginia": "WV", Wisconsin: "WI",
  Wyoming: "WY", "Puerto Rico": "PR"
}

// Connects to data-controller="us-map-chart"
// Renders a US states choropleth: each state filled by its registrant count.
export default class extends Controller {
  static targets = ["canvas"]
  // counts: registrant count keyed by state abbreviation, e.g. { "CA": 5, "NY": 2 }.
  // color: base hex for the choropleth ramp (light tint → this color); defaults to blue.
  static values = { counts: Object, color: { type: String, default: "#3b82f6" } }

  async connect() {
    // Load the geo plugin and the (large) TopoJSON only on pages that use the map.
    const [ geo, atlas ] = await Promise.all([
      import("chartjs-chart-geo"),
      import("us-atlas/states-10m.json")
    ])
    if (this.disconnected) return

    const { ChoroplethController, GeoFeature, ColorScale, ProjectionScale, topojson } = geo
    Chart.register(ChoroplethController, GeoFeature, ColorScale, ProjectionScale)

    const us = atlas.default || atlas
    const nation = topojson.feature(us, us.objects.nation).features[0]
    const states = topojson.feature(us, us.objects.states).features

    const counts = this.countsValue
    const valueFor = (feature) => {
      const name = feature.properties.name
      return counts[abbrByStateName[name]] ?? counts[name] ?? 0
    }

    // Adjust bc one over-represented state (e.g. CA) left every other state near-white.
    const values = states.map(valueFor)
    const highest = Math.max(0, ...values)
    const secondHighest = Math.max(0, ...values.filter(v => v < highest))
    const colorScaleMax = Math.max(1, Math.ceil((secondHighest || highest) * 1.4))

    this.chart = new Chart(this.canvasTarget, {
      type: "choropleth",
      data: {
        labels: states.map(s => s.properties.name),
        datasets: [ {
          label: "Registrants",
          outline: nation,
          data: states.map(s => ({ feature: s, value: valueFor(s) }))
        } ]
      },
      options: {
        maintainAspectRatio: false,
        showOutline: true,
        showGraticule: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => `${ctx.chart.data.labels[ctx.dataIndex]}: ${ctx.raw.value}`
            }
          }
        },
        scales: {
          projection: { axis: "x", projection: "albersUsa" },
          color: {
            axis: "x",
            min: 0,
            max: colorScaleMax,
            quantize: 5,
            interpolate: rampTo(this.colorValue),
            legend: { position: "bottom-right", align: "bottom" }
          }
        }
      }
    })
  }

  disconnect() {
    this.disconnected = true
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}
