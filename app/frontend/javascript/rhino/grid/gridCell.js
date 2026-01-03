import {
  Node,
  mergeAttributes,
  findParentNodeClosestToPos,
} from "@tiptap/core";

export const GridCell = Node.create({
  name: "gridCell",
  group: "block",
  content: "block+",
  isolating: true,

  addAttributes() {
    return {
      verticalAlign: {
        default: "top", // top | center | bottom
      },
      columnSpan: {
        default: 1,
      },
      hasBorder: {
        default: true,
      },
    };
  },

  parseHTML() {
    return [{ tag: "div[data-type='grid-cell']" }];
  },

  renderHTML({ node, HTMLAttributes }) {
    const alignClasses = {
      top: "justify-start",
      center: "justify-center",
      bottom: "justify-end",
    };

    const colSpanClasses = {
      1: "col-span-1",
      2: "col-span-2",
      3: "col-span-3",
      4: "col-span-4",
      5: "col-span-5",
      6: "col-span-6",
    };

    const verticalClass =
      alignClasses[node.attrs.verticalAlign] || alignClasses.top;
    const spanClass =
      colSpanClasses[node.attrs.columnSpan] || colSpanClasses[1];

    // Border class: solid if hasBorder, otherwise helper class for editor CSS
    const borderClass = node.attrs.hasBorder ? "border border-gray-300" : "";

    return [
      "div",
      mergeAttributes(HTMLAttributes, {
        "data-type": "grid-cell",
        hasborder: node.attrs.hasBorder ? "true" : "false",
        class: [
          "grid-cell-editor",
          borderClass,
          "p-3 rounded flex flex-col",
          verticalClass,
          spanClass,
        ]
          .filter(Boolean)
          .join(" "),
      }),
      0,
    ];
  },

  addCommands() {
    return {
      toggleCellBorder:
        () =>
        ({ state, dispatch }) => {
          const cell = findParentNodeClosestToPos(
            state.selection.$from,
            (node) => node.type.name === "gridCell",
          );
          if (!cell) return false;

          const { pos, node } = cell;
          const tr = state.tr.setNodeMarkup(pos, undefined, {
            ...node.attrs,
            hasBorder: !node.attrs.hasBorder,
          });

          if (dispatch) dispatch(tr);
          return true;
        },
      setVerticalAlign:
        (alignment) =>
        ({ state, dispatch }) => {
          const cell = findParentNodeClosestToPos(
            state.selection.$from,
            (node) => node.type.name === "gridCell",
          );
          if (!cell) return false;

          const tr = state.tr.setNodeMarkup(cell.pos, undefined, {
            ...cell.node.attrs,
            verticalAlign: alignment,
          });

          if (dispatch) dispatch(tr);
          return true;
        },
      setColumnSpan:
        (span) =>
        ({ state, dispatch }) => {
          const cell = findParentNodeClosestToPos(
            state.selection.$from,
            (node) => node.type.name === "gridCell",
          );
          if (!cell) return false;

          const grid = findParentNodeClosestToPos(
            state.selection.$from,
            (node) => node.type.name === "grid",
          );
          if (!grid) return false;

          const max = grid.node.attrs.columns || 1;
          const safeSpan = Math.max(1, Math.min(span, max));

          const tr = state.tr.setNodeMarkup(cell.pos, undefined, {
            ...cell.node.attrs,
            columnSpan: safeSpan,
          });

          if (dispatch) dispatch(tr);
          return true;
        },
    };
  },
});
