import "@hotwired/turbo-rails";
import "@rails/actiontext";
import "rhino-editor";
import "rhino-editor/exports/styles/trix.css";

import "./controllers";
// import "./rhino/extend-editor.js";
// Lazy-load the custom editor only when needed
document.addEventListener("rhino-before-initialize", async (event) => {
  // Dynamically import your extended editor + all Tiptap/ProseMirror deps
  await import("./rhino/extend-editor.js");
});
