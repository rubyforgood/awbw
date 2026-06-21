// Opens the shared, styled confirmation modal and resolves to the user's choice.
//
// Returns a Promise<boolean> so it can stand in for window.confirm() in async
// flows and as Turbo's confirm method (see application.js). The request is
// dispatched as a "confirm-modal:open" window event carrying the message,
// options, and a resolve callback; the confirm-modal Stimulus controller
// (rendered once in the layout) handles it and calls preventDefault.
//
// If the controller isn't on the page (e.g. an unusual layout) we fall back to
// the browser's native confirm() so a missing modal never silently blocks an
// action.
export function confirmModal(message, options = {}) {
  return new Promise((resolve) => {
    const event = new CustomEvent("confirm-modal:open", {
      detail: { message, options, resolve },
      cancelable: true,
    });

    const handled = !window.dispatchEvent(event);
    if (!handled) resolve(window.confirm(message));
  });
}
