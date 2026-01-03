import { html } from "lit";
import "rhino-editor/exports/styles/trix.css";
import { findParentNodeClosestToPos } from "@tiptap/core";

export function renderGridMenu(editor) {
  if (!editor || !editor.isActive("grid")) return html``;

  const buttons = [
    {
      title: "Delete Grid",
      icon: "🗑",
      action: () => editor.chain().focus().deleteGrid().run(),
    },
    {
      title: "Add Cell",
      icon: "＋",
      action: () => editor.chain().focus().addGridCell().run(),
    },
    {
      title: "Delete Cell",
      icon: "−",
      action: () => editor.chain().focus().deleteLastGridCell().run(),
    },

    {
      title: "Toggle Border",
      icon: "border",
      action: () => editor.chain().focus().toggleCellBorder().run(),
    },

    {
      title: "Add Column",
      icon: "＋",
      action: () => editor.chain().focus().increaseGridColumns().run(),
    },

    {
      title: "Remove Column",
      icon: "−",
      action: () => editor.chain().focus().decreaseGridColumns().run(),
    },

    {
      title: "Set Column Span",
      icon: "S",
      action: () => {
        if (!editor) return;

        const { state } = editor;

        const gridCell = findParentNodeClosestToPos(
          state.selection.$from,
          (node) => node.type.name === "gridCell",
        );
        if (!gridCell) return;

        const parentGrid = findParentNodeClosestToPos(
          state.selection.$from,
          (node) => node.type.name === "grid",
        );
        if (!parentGrid) return;

        const maxColumns = parentGrid.node.attrs.columns;

        const span = prompt(
          `Enter column span (1–${maxColumns}):`,
          gridCell.node.attrs.columnSpan,
        );
        const num = parseInt(span, 10);

        if (!num || num < 1 || num > maxColumns) {
          alert(
            `Invalid input! Please enter a number between 1 and ${maxColumns} or add more columns first.`,
          );
          return;
        }

        if (editor.chain) {
          editor.chain().focus().setColumnSpan(num).run();
        }
      },
    },
    {
      title: "Align Top",
      icon: "↑",
      action: () => editor.chain().focus().setVerticalAlign("top").run(),
    },
    {
      title: "Align Center",
      icon: "↕",
      action: () => editor.chain().focus().setVerticalAlign("center").run(),
    },
    {
      title: "Align Botton",
      icon: "↓",
      action: () => editor.chain().focus().setVerticalAlign("bottom").run(),
    },
  ];

  return html`
    <role-toolbar class="toolbar" part="toolbar" role="toolbar">
      ${buttons.map(
        (btn) => html`
          <button
            class="toolbar__button rhino-toolbar-button"
            type="button"
            title=${btn.title}
            data-role="toolbar-item"
            aria-disabled="false"
            @click=${btn.action}
          >
            <role-tooltip hoist part="toolbar-tooltip toolbar-tooltip__table">
              ${btn.tooltip}
            </role-tooltip>
            <span part="toolbar__icon">${btn.icon}</span>
          </button>
        `,
      )}
    </role-toolbar>
  `;
}
