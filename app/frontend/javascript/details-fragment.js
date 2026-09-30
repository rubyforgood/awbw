// Form sections render as collapsed <details> (#comments-section, #affiliations,
// #addresses, #professional-licenses). Links deep-link into them by URL fragment
// — a comment icon pointing at #comments-section, the affiliation editor
// returning to #affiliations — and a fragment never reaches the server, so the
// section has to be expanded here or the link lands on a closed summary.
const openSectionFromHash = () => {
  const id = window.location.hash.slice(1);
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

addEventListener("turbo:load", openSectionFromHash);
addEventListener("hashchange", openSectionFromHash);
