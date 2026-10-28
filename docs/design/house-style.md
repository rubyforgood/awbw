# House UI style

Reusable UI patterns for this app (Rails + Tailwind + Stimulus + Turbo). Read this
before building or reshaping UI so new work matches the house patterns instead of
reinventing them. When you add a pattern worth reusing, document it here.

Related:

- Domain accent colors come from `DomainTheme` (`lib/domain_theme.rb`) — match a
  page's accent to its domain rather than hard-coding a color.
- The awbw.org marketing brand (navy, cream, gold, Fraunces) is captured in
  [the design reference screenshots](README.md) and
  `app/assets/images/brand/awbw-brand-guide.pdf`.

## Table view toggles

When a table needs to reshape what it shows without leaving the page, we use two
complementary controls, both showcased together in the **events registrants
toolbar** (`app/views/events/_registrants_results.html.erb`).

### 1. Segmented display toggle

Swaps what the table shows on a reload: *which rows* (a filter over the dataset)
or *which layout variant* renders. Server-driven: each segment is a `link_to`
inside a pill `<nav>` carrying the state in a query param, so the choice is
shareable/bookmarkable. Canonical uses:

- The **Active / Inactive** registrant filter, each segment carrying its count.
- The scholarships report's **Separate # & $ / Combined** layout toggle
  (`app/views/events/_scholarships_report_toggle.html.erb`), which merges a `view`
  param onto the current filters
  (`request.query_parameters.merge("view" => "combined")`) so the controller
  renders a different partial. Keep the param sticky across filter changes with a
  `hidden_field_tag :view` in the filter form.

```erb
<nav class="inline-flex rounded-lg bg-gray-100 p-0.5 text-sm font-medium" aria-label="Attendance filter">
  <%= link_to registrants_event_path(@event, status_filter: "active"),
        data: { turbo_frame: "_top" },
        class: "px-3 py-1 rounded-md transition-colors #{selected ? "bg-white text-gray-800 shadow-sm" : eyebrow_link_class}" do %>
    Active <span class="text-gray-400">(<%= @active_count %>)</span>
  <% end %>
  <%# …Inactive segment… %>
</nav>
```

- Track `bg-gray-100 p-0.5`; **selected** segment `bg-white text-gray-800
  shadow-sm`, **unselected** `eyebrow_link_class` (`text-gray-500
  hover:text-gray-700`); counts in `text-gray-400`.
- On a domain-themed page, tint the track and unselected text with the domain
  accent (the scholarships toggle uses `bg-fuchsia-100` / `text-fuchsia-700`).

### 2. Slide switch (column toggle)

Toggles *how the table looks* — which optional columns show — instantly,
client-side. Render the shared partial rather than copying its markup:

```erb
<div data-column-toggle-root data-column-toggle-scope="form-submissions">
  <%= render "shared/column_toggle_switch", group: "event", label: "Event", on: true %>

  <table>
    <th data-column-toggle-col="event">Event</th>
    <%# …and the same data-column-toggle-col="event" on each matching <td> %>
  </table>
</div>
```

- `shared/_column_toggle_switch.html.erb` takes `group`, `label`, and `on`
  (default `false`). A visually-hidden checkbox drives the track + knob; the
  track is `bg-blue-600` when on and `bg-gray-300` when off.
- Backed by the **`column-toggle`** Stimulus controller
  (`app/frontend/javascript/controllers/column_toggle_controller.js`): it
  shows/hides every cell whose `data-column-toggle-col` matches the switch's
  `group`, within the nearest `[data-column-toggle-root]`. A column that starts
  hidden also needs `hidden` on its cells.
- The chosen state is remembered in `sessionStorage`, namespaced by
  `data-column-toggle-scope` (e.g. the event id), so it survives Turbo frame
  re-renders. Give each table its own scope.
- Example: `app/views/form_submissions/form_submissions_results.html.erb`.

### Choosing between them

- Want the choice shareable/in the URL, or the two variants differ structurally
  (different colspans/headers, a different partial) → **segmented toggle** with a
  query param and a full reload.
- Want it instant and local, hiding a subset of existing columns → **slide
  switch** (`column-toggle`).
