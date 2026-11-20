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

- `shared/_column_toggle_switch.html.erb` takes `group`, `label`, `on`
  (default `false`), and `stacked` (default `false`). A visually-hidden checkbox
  drives the track + knob; the track is `bg-blue-600` when on and `bg-gray-300`
  when off.
- On a crowded switch row, pass `stacked: true` on every switch: a multi-word
  label breaks before its last word, so labels stay as narrow as possible and
  each slider sits right after its label (a label left to wrap on its own keeps
  its one-line width and leaves a gap). Example: the event registrants list.
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

## Tables on small screens

When a results table can't fit a phone or tablet, render the same rows twice in
the results view: a card list for small screens and the table for large ones. The
users index (`app/views/users/users_results.html.erb`) is the reference.

- Wrap the cards in `lg:hidden` and the table in `hidden lg:block`; pick the
  breakpoint where the table first fits without horizontal scroll.
- Extract each cell's content into a partial both layouts render, so a status
  icon or action button changes in one place.
- Each card leads with the row's identity card (e.g. the person button) and its
  actions on one line, then the remaining fields below, ending with a wrapping
  `<dl>` of muted label + value pairs.
- Keep sorting on small screens: render the **Sort by strip** (below) above the
  cards, in link mode, with the same sort/direction params as the table headers.
- Let long unbroken values (emails, URLs) wrap with `wrap-anywhere`, plus a
  `<wbr>` at the natural break (before the `@`).

## Toggle chevrons

Show / hide and expand / collapse controls put the chevron **after** the label
(`Collapse all ⌃`, `Hide recipients ⌃`), sized `text-xs`, pointing down when
closed and rotating up when open. `events/_charts_toggle_bar` and
`events/_panel_cta` are the reference. A chevron leads only on a disclosure row
whose whole row is the click target (an accordion header), where it marks the
row's state before its title.

## Sort by strip

Card and list pages sort with one control: `shared/_sort_strip`, a "Sort by"
label beside a segmented strip whose active segment fills with the domain's 700
color. Tables sort by clicking column headers (`sort_header_link`) instead; a
table's small-screen card list uses the strip.

- **Radio mode** (no `href:`) — inside a search form wired to the `collection`
  controller, so a click auto-submits; `has-checked` styles the active segment
  with no JS. `default:` names the value that submits blank, so the server
  re-derives the default. Workshops and resources are the reference.
- **Link mode** (`href: ->(value) { path }`) — the server marks the active
  segment with `aria-current`. Pass `link_data: { turbo_frame: … }` inside a
  results frame. For a reversible sort, point the active segment's href at the
  opposite direction and pass `active_icon:` (`fa-arrow-up` / `fa-arrow-down`).
  My Bookmarks and the users small-screen cards are the reference.
- Options are a `{ label => value }` constant beside the sort logic (e.g.
  `WorkshopSearchService::SORT_OPTIONS`); labels are sentence case.
- Place it at the right end of the count row (`ml-auto`) on index pages.
