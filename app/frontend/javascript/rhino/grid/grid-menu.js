import { html } from "lit";
import "rhino-editor/exports/styles/trix.css"

/**
 * Render the grid menu toolbar (like table menu)
 * @param {Editor} editor - Tiptap editor instance
 */
export function renderGridMenu(editor) {
  if (!editor || !editor.isActive("grid")) return html``;

  const buttons = [
    {
      title: "Add Row",
      icon: "＋",
      action: () => editor.chain().focus().addGridRow().run(),
    },
    {
      title: "Add Column",
      icon: "＋",
      action: () => editor.chain().focus().addGridColumn().run(),
    },
    {
      title: "Add Cell",
      icon: "＋",
      action: () => editor.chain().focus().addGridCell().run(),
    },
    {
      title: "Delete Cell",
      icon: "-",
      action: () => editor.chain().focus().deleteGridCell().run(),
    },
    {
      title: "Delete Grid",
      icon: "🗑",
      action: () => editor.chain().focus().deleteGrid().run(),
    },
  ];

  return html`
    <role-toolbar class="toolbar" part="toolbar" role="toolbar">
      ${buttons.map(
        btn => html`
          <button
            class="toolbar__button rhino-toolbar-button"
            type="button"
            title=${btn.title}
            data-role="toolbar-item"
            aria-disabled="false"
            @click=${btn.action}
          >
            <role-tooltip
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
            >
              ${btn.tooltip}
            </role-tooltip>
            <span part="toolbar__icon">${btn.icon}</span>
          </button>
        `
      )}
    </role-toolbar>
  `;
}
