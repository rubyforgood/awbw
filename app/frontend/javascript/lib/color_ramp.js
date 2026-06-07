// Builds a chart.js-geo choropleth interpolate(t) function that ramps from a
// near-white floor (so low counts stay legible) up to the given base color.
// Lets each map be themed by a single hex (e.g. the addresses/slate color).
export function rampTo(base) {
  const from = [ 241, 245, 249 ] // slate-100 floor for the lowest counts
  const to = hexToRgb(base)
  return (t) => {
    const channels = from.map((value, i) => Math.round(value + (to[i] - value) * t))
    return `rgb(${channels[0]}, ${channels[1]}, ${channels[2]})`
  }
}

function hexToRgb(hex) {
  const clean = hex.replace("#", "")
  return [ 0, 2, 4 ].map((i) => parseInt(clean.slice(i, i + 2), 16))
}
