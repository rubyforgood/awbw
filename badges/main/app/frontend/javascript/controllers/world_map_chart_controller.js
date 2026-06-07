import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"
import { rampTo } from "../lib/color_ramp"

// A few world-atlas country names differ from the common names our address data
// stores; map atlas name → our key so those countries still fill. Unmatched
// countries fall back to 0 (the legend table still lists their exact counts).
const aliasByAtlasName = {
  "united states of america": "united states",
  "united republic of tanzania": "tanzania",
  "republic of korea": "south korea",
  "dem. rep. korea": "north korea",
  "russian federation": "russia",
  "czechia": "czech republic",
  "bosnia and herz.": "bosnia and herzegovina",
  "dominican rep.": "dominican republic"
}

// Connects to data-controller="world-map-chart"
// Renders a world choropleth: each country filled by its registrant count.
export default class extends Controller {
  static targets = ["canvas"]
  // counts: registrant count keyed by country name, e.g. { "Canada": 3 }.
  // color: base hex for the choropleth ramp (light tint → this color); defaults to blue.
  static values = { counts: Object, color: { type: String, default: "#3b82f6" } }

  async connect() {
    // Load the geo plugin and the (large) TopoJSON only on pages that use the map.
    const [ geo, atlas ] = await Promise.all([
      import("chartjs-chart-geo"),
      import("world-atlas/countries-110m.json")
    ])
    if (this.disconnected) return

    const { ChoroplethController, GeoFeature, ColorScale, ProjectionScale, topojson } = geo
    Chart.register(ChoroplethController, GeoFeature, ColorScale, ProjectionScale)

    const world = atlas.default || atlas
    const countries = topojson.feature(world, world.objects.countries).features
    const land = topojson.feature(world, world.objects.land).features[0]

    const norm = (value) => String(value).toLowerCase().trim()
    const countsByName = {}
    Object.entries(this.countsValue).forEach(([ name, count ]) => { countsByName[norm(name)] = count })
    const valueFor = (feature) => {
      const name = norm(feature.properties.name)
      return countsByName[name] ?? countsByName[aliasByAtlasName[name]] ?? 0
    }

    this.chart = new Chart(this.canvasTarget, {
      type: "choropleth",
      data: {
        labels: countries.map(c => c.properties.name),
        datasets: [ {
          label: "Registrants",
          outline: land,
          data: countries.map(c => ({ feature: c, value: valueFor(c) }))
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
          projection: { axis: "x", projection: "equalEarth" },
          color: {
            axis: "x",
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
