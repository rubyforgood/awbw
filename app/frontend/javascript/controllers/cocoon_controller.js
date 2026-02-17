import { Controller } from "@hotwired/stimulus";

// Vanilla JS replacement for the cocoon gem's jQuery-dependent JavaScript.
// Handles link_to_add_association and link_to_remove_association clicks.
// Attach to any persistent element (e.g. <body data-controller="cocoon">).

let counter = 0;
let globalListenerInstalled = false;
let activeInstance = null;

function uniqueId() {
  return new Date().getTime() + counter++;
}

function getInsertionInfo(link) {
  const nodeSel = link.dataset.associationInsertionNode;
  const traversal = link.dataset.associationInsertionTraversal;
  const method =
    link.dataset.associationInsertionMethod ||
    link.dataset.associationInsertionPosition ||
    "before";
  let node;

  if (nodeSel) {
    if (nodeSel === "this") {
      node = link;
    } else if (traversal === "closest") {
      node = link.closest(nodeSel);
    } else if (traversal) {
      node = link.closest(nodeSel) || document.querySelector(nodeSel);
    } else {
      node = document.querySelector(nodeSel);
    }
  } else {
    node = link.parentElement;
  }

  return { node, method };
}

function insertContent(node, method, element) {
  switch (method) {
    case "append":
      node.appendChild(element);
      break;
    case "prepend":
      node.insertBefore(element, node.firstChild);
      break;
    case "after":
      node.insertAdjacentElement("afterend", element);
      break;
    case "before":
    default:
      node.insertAdjacentElement("beforebegin", element);
      break;
  }
}

function fireCocoonEvent(target, name, detail) {
  return target.dispatchEvent(
    new CustomEvent(name, { bubbles: true, cancelable: true, detail })
  );
}

function handleAdd(link, originalEvent) {
  const template = link.dataset.associationInsertionTemplate;
  const association = link.dataset.association;
  const associations = link.dataset.associations;
  const count = parseInt(link.dataset.count) || 1;
  const { node, method } = getInsertionInfo(link);

  if (!template || !node) return;

  for (let i = 0; i < count; i++) {
    const id = uniqueId();

    let regexBraces = new RegExp(
      "\\[new_" + association + "\\](.*?\\[)",
      "g"
    );
    let regexUnderscores = new RegExp(
      "_new_" + association + "_(.*?_)",
      "g"
    );
    let html = template.replace(regexBraces, "[" + id + "]$1");

    if (html === template && associations) {
      regexBraces = new RegExp(
        "\\[new_" + associations + "\\](.*?\\[)",
        "g"
      );
      regexUnderscores = new RegExp(
        "_new_" + associations + "_(.*?_)",
        "g"
      );
      html = template.replace(regexBraces, "[" + id + "]$1");
    }

    html = html.replace(regexUnderscores, "_" + id + "_$1");

    const wrapper = document.createElement("div");
    wrapper.innerHTML = html.trim();
    const newElement = wrapper.firstElementChild || wrapper;

    const allowed = fireCocoonEvent(node, "cocoon:before-insert", {
      item: newElement,
      originalEvent,
    });

    if (allowed) {
      insertContent(node, method, newElement);
      fireCocoonEvent(node, "cocoon:after-insert", {
        item: newElement,
        originalEvent,
      });
    }
  }
}

function handleRemove(link, originalEvent) {
  const wrapperClass = link.dataset.wrapperClass || "nested-fields";
  const wrapper = link.closest("." + wrapperClass);
  if (!wrapper) return;

  const triggerNode = wrapper.parentElement || wrapper;

  const allowed = fireCocoonEvent(triggerNode, "cocoon:before-remove", {
    item: wrapper,
    originalEvent,
  });

  if (allowed) {
    const timeout = parseInt(triggerNode.dataset.removeTimeout) || 0;

    setTimeout(() => {
      if (link.classList.contains("dynamic")) {
        wrapper.remove();
      } else {
        const input = wrapper.querySelector("input[name*='_destroy']");
        if (input) input.value = "1";
        wrapper.style.display = "none";
      }

      fireCocoonEvent(triggerNode, "cocoon:after-remove", {
        item: wrapper,
        originalEvent,
      });
    }, timeout);
  }
}

function globalClickHandler(e) {
  const addLink = e.target.closest("[data-association-insertion-template]");
  if (addLink) {
    e.preventDefault();
    e.stopImmediatePropagation();
    handleAdd(addLink, e);
    return;
  }

  const removeLink =
    e.target.closest(".remove_fields") ||
    e.target.closest("[data-cocoon-remove]");
  if (removeLink) {
    e.preventDefault();
    e.stopImmediatePropagation();
    handleRemove(removeLink, e);
  }
}

// Install the global listener immediately when this module loads.
// This runs once regardless of whether the Stimulus controller connects.
if (!globalListenerInstalled) {
  document.addEventListener("click", globalClickHandler, true);
  globalListenerInstalled = true;
  console.log("[cocoon] click handler installed");
}

export default class extends Controller {
  connect() {
    activeInstance = this;
  }

  disconnect() {
    activeInstance = null;
  }
}
