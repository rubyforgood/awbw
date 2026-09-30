// Form sections render as collapsed <details> (#comments-section, #affiliations,
// #addresses, #professional-licenses). Links deep-link into them by URL fragment
// — a comment icon pointing at #comments-section, the affiliation editor
// returning to #affiliations — and a fragment never reaches the server, so the
// section has to be expanded here or the link lands on a closed summary.
const expandSection = (id) => {
  if (!id) return;

  const target = document.getElementById(id);
  if (!target) return;

  let expanded = false;
  let section = target.closest("details");
  while (section) {
    if (!section.open) {
      section.open = true;
      expanded = true;
    }
    section = section.parentElement?.closest("details");
  }

  // Only re-scroll when something was actually expanded: the browser already
  // scrolled to the fragment, and expanding above it moves the target down.
  if (!expanded) return;
  requestAnimationFrame(() => target.scrollIntoView({ block: "start" }));
};

const expandFromHash = () => expandSection(window.location.hash.slice(1));

addEventListener("turbo:load", expandFromHash);
addEventListener("hashchange", expandFromHash);

// A same-page anchor click fires no hashchange when it re-targets the fragment
// already in the URL, so a section collapsed again after the first click would
// stay shut on every click after it (the workshop form's age-range comment chips
// all point at #comments-section).
addEventListener("click", (event) => {
  const link = event.target.closest?.("a[href^='#']");
  if (link) expandSection(link.getAttribute("href").slice(1));
});
