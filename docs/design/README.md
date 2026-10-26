# AWBW marketing-site reference

Reference screenshots of the new awbw.org marketing brand, used as the design
source for restyling the facilitator portal (starting with the person profile).
They establish the visual language: navy hero, cream surfaces, gold accents,
serif (Fraunces) display type, rainbow accent strip, and colored-border cards.

Resized to 1600px wide and saved as JPEG (reference only, not shipped in the UI).

- `awbw-home-*` — the awbw.org home page, top to bottom.
- `awbw-training-*` — the on-demand training page, top to bottom.
- `awbw-home-hero-review-markup` — the home hero captured with the Pastel
  review toolbar visible.

Brand fundamentals live in `app/assets/images/brand/awbw-brand-guide.pdf`.

## House UI patterns

Reusable UI patterns for this app (Rails + Tailwind + Stimulus + Turbo). Match
these instead of reinventing them.

### Table view toggles (+ the sliders)

When a table needs to reshape what it shows without leaving the page, we use two
complementary controls, both showcased together in the **events registrants
toolbar** (`app/views/events/_registrants_results.html.erb`) — the best example
to copy from.

**1. Segmented display toggle** — swaps what the table shows on a reload:
*which rows* (a filter over the dataset) or *which layout variant* renders.
Server-driven: each segment is a `link_to` inside a pill `<nav>` carrying the
state in a query param, so the choice is shareable/bookmarkable. Canonical uses:
the **Active / Inactive** registrant filter (each segment carrying its count),
and the scholarships report's **Separate # & $ / Combined** layout toggle, which
merges a `view` param onto the current filters
(`request.query_parameters.merge("view" => "combined")`) so the controller renders
a different partial (`app/views/events/_scholarships_report.html.erb`). Keep the
param sticky across filter changes with a `hidden_field_tag :view` in the filter
form.

```erb
<nav class="inline-flex rounded-lg bg-gray-100 p-0.5 text-sm font-medium" aria-label="Attendance filter">
  <%= link_to registrants_event_path(@event, status_filter: "active"),
        data: { turbo_frame: "_top" },
        class: "px-3 py-1 rounded-md transition-colors #{selected ? "bg-white text-gray-800 shadow-sm" : "text-gray-500 hover:text-gray-700"}" do %>
    Active <span class="text-gray-400">(<%= @active_count %>)</span>
  <% end %>
  <%# …Inactive segment… %>
</nav>
```

- Track `bg-gray-100 p-0.5`; **selected** segment `bg-white text-gray-800
  shadow-sm`, **unselected** `text-gray-500 hover:text-gray-700`; counts in
  `text-gray-400`.
- Prefer this when the states are mutually exclusive and the choice should be
  shareable/bookmarkable (it lives in a query param).

**2. Slide switch ("the sliders")** — toggles *how the table looks* (columns or
cell layout) instantly, client-side via Stimulus. A visually-hidden checkbox
drives a track + knob; the same markup is reused everywhere:

```erb
<label class="inline-flex items-center gap-2 cursor-pointer select-none"
       data-controller="column-toggle" data-column-toggle-group-value="organization">
  <span class="text-sm text-gray-500">Linked organization</span>
  <input type="checkbox" checked class="sr-only"
         data-column-toggle-target="toggle" data-action="column-toggle#toggle">
  <span class="relative inline-block w-9 h-5">
    <span data-column-toggle-target="track" class="absolute inset-0 rounded-full bg-blue-600 transition-colors"></span>
    <span data-column-toggle-target="knob" class="absolute top-0.5 left-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform" style="transform: translateX(16px)"></span>
  </span>
</label>
```

- Knob travel is `translateX(16px)` for the `w-9 h-5` track; track goes to
  `bg-gray-300` when off and an accent (`bg-blue-600`, or the domain accent) when
  on. Keep the checkbox `sr-only` — the track/knob are the visible control.
- Backed by the **`column-toggle`** Stimulus controller: it shows/hides the set
  of columns whose `data-column-toggle-col` matches the switch's `group` value,
  within a `[data-column-toggle-root]` ancestor. Use for optional columns
  (registrants: Linked organization, CE).

**Choosing between them:** want the choice shareable/in the URL, or the two
variants differ structurally (different colspans/headers, a different partial) →
**segmented nav** with a query param and a full reload. Want it instant and
local, hiding a subset of existing columns → **slide switch** (`column-toggle`).
Match the accent color to the page's domain theme (`DomainTheme`), e.g. fuchsia
for scholarships.
