import {
  Node,
  mergeAttributes,
  findParentNodeClosestToPos,
} from "@tiptap/core";
import { TextSelection } from "@tiptap/pm/state";

export const Grid = Node.create({
  name: "grid",
  group: "block",
  content: "gridCell+",
  isolating: true,

  addAttributes() {
    return {
      columns: {
        default: 1,
      },
    };
  },

  parseHTML() {
    return [{ tag: 'div[data-type="grid"]' }];
  },

  renderHTML({ node, HTMLAttributes }) {
    const GRID_COL_CLASSES = {
      1: "grid-cols-1",
      2: "grid-cols-2",
      3: "grid-cols-3",
      4: "grid-cols-4",
      5: "grid-cols-5",
      6: "grid-cols-6",
    };
    const colsClass =
      GRID_COL_CLASSES[node.attrs.columns] || GRID_COL_CLASSES[1];
    return [
      "div",
      mergeAttributes(HTMLAttributes, {
        "data-type": "grid",
        class: `grid gap-4 ${colsClass}`,
      }),
      0,
    ];
  },

  addCommands() {
    return {
      /**
       * Insert a grid with ONE cell
       */
      insertGrid:
        () =>
        ({ tr, dispatch, editor }) => {
          const { schema } = editor;

          const gridNode = schema.nodes.grid.create({ columns: 1 }, [
            schema.nodes.gridCell.create({}, [schema.nodes.paragraph.create()]),
          ]);

          if (!dispatch) return true;

          const pos = tr.selection.from;

          tr.replaceSelectionWith(gridNode);
          tr.setSelection(TextSelection.near(tr.doc.resolve(pos + 1)));
          tr.scrollIntoView();

          dispatch(tr);
          return true;
        },

      addGridCell:
        () =>
        ({ state, dispatch }) => {
          const { selection, tr, schema } = state;

          const grid = findParentNodeClosestToPos(
            selection.$from,
            (node) => node.type.name === "grid",
          );
          if (!grid) return false;

          const insertPos = grid.pos + grid.node.nodeSize - 1;

          const newCell = schema.nodes.gridCell.create({}, [
            schema.nodes.paragraph.create(),
          ]);

          tr.insert(insertPos, newCell);

          if (dispatch) dispatch(tr);
          return true;
        },

      deleteLastGridCell:
        () =>
        ({ state, dispatch }) => {
          const { selection, tr } = state;

          const grid = findParentNodeClosestToPos(
            selection.$from,
            (node) => node.type.name === "grid",
          );
          if (!grid) return false;

          const cellCount = grid.node.childCount;
          if (cellCount <= 1) return true; // keep at least one cell

          // Position of last cell
          let offset = 0;
          for (let i = 0; i < cellCount - 1; i++) {
            offset += grid.node.child(i).nodeSize;
          }

          const lastCellPos = grid.pos + offset + 1;
          const lastCell = grid.node.child(cellCount - 1);

          tr.delete(lastCellPos, lastCellPos + lastCell.nodeSize);

          if (dispatch) dispatch(tr);
          return true;
        },
      increaseGridColumns:
        () =>
        ({ state, dispatch }) => {
          const { selection, tr } = state;

          const grid = findParentNodeClosestToPos(
            selection.$from,
            (node) => node.type.name === "grid",
          );
          if (!grid) return false;

          const current = grid.node.attrs.columns || 1;
          const next = Math.min(current + 1, 6);

          if (next === current) return true;

          tr.setNodeMarkup(grid.pos, undefined, {
            ...grid.node.attrs,
            columns: next,
          });

          if (dispatch) dispatch(tr);
          return true;
        },

      decreaseGridColumns:
        () =>
        ({ state, dispatch }) => {
          const { selection, tr } = state;

          const grid = findParentNodeClosestToPos(
            selection.$from,
            (node) => node.type.name === "grid",
          );
          if (!grid) return false;

          const currentCols = grid.node.attrs.columns || 1;
          const nextCols = Math.max(currentCols - 1, 1);

          if (nextCols === currentCols) return true;

          // Update grid columns
          tr.setNodeMarkup(grid.pos, undefined, {
            ...grid.node.attrs,
            columns: nextCols,
          });

          // Clamp cell spans if needed
          grid.node.forEach((child, offset) => {
            if (child.type.name !== "gridCell") return;

            if (child.attrs.columnSpan > nextCols) {
              tr.setNodeMarkup(grid.pos + offset + 1, undefined, {
                ...child.attrs,
                columnSpan: nextCols,
              });
            }
          });

          if (dispatch) dispatch(tr);
          return true;
        },
      /**
       * Delete entire grid
       */
      deleteGrid:
        () =>
        ({ state, dispatch }) => {
          const { selection, tr } = state;

          const grid = findParentNodeClosestToPos(
            selection.$from,
            (node) => node.type.name === "grid",
          );
          if (!grid) return false;

          tr.delete(grid.pos, grid.pos + grid.node.nodeSize);
          tr.setSelection(TextSelection.near(tr.doc.resolve(grid.pos)));

          if (dispatch) dispatch(tr);
          return true;
        },
    };
  },
});
