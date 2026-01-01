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
        default: "top",
      },
      columnSpan: {
        default: 1,
      },
    };
  },

  parseHTML() {
    return [{ tag: 'div[data-type="grid-cell"]' }];
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

    return [
      "div",
      mergeAttributes(HTMLAttributes, {
        "data-type": "grid-cell",
        class: `border border-gray-300 p-3 rounded flex flex-col ${verticalClass} ${spanClass}`,
      }),
      0,
    ];
  },

  addCommands() {
    return {
      setVerticalAlign:
        (alignment) =>
        ({ state, dispatch }) => {
          const gridCell = findParentNodeClosestToPos(
            state.selection.$from,
            (node) => node.type.name === "gridCell",
          );
          if (!gridCell) return false;

          const { pos, node } = gridCell;
          const tr = state.tr.setNodeMarkup(pos, undefined, {
            ...node.attrs,
            verticalAlign: alignment,
          });

          if (dispatch) dispatch(tr);
          return true;
        },

      // setColumnSpan: span => ({ state, dispatch }) => {
      //   const gridCell = findParentNodeClosestToPos(
      //     state.selection.$from,
      //     node => node.type.name === 'gridCell'
      //   )
      //   if (!gridCell) return false
      //
      //   const { pos, node } = gridCell
      //
      //   const parentGrid = findParentNodeClosestToPos(
      //     state.selection.$from,
      //     node => node.type.name === 'grid'
      //   )
      //   if (!parentGrid) return false
      //
      //   const maxColumns = parentGrid.node.attrs.columns
      //
      //   const newSpan = Math.min(span, maxColumns)
      //
      //   const tr = state.tr.setNodeMarkup(pos, undefined, {
      //     ...node.attrs,
      //     columnSpan: newSpan,
      //   })
      //
      //   if (dispatch) dispatch(tr)
      //   return true
      // },
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

          const max = grid.node.attrs.columns;
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
