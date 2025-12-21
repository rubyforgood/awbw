import { Node, mergeAttributes, findParentNodeClosestToPos } from '@tiptap/core'
import { TextSelection } from '@tiptap/pm/state'

export const Grid = Node.create({
  name: 'grid',
  group: 'block',
  content: 'gridCell+',
  isolating: true,

  addAttributes() {
    return {
      columns: { default: 2 },
      rows: { default: 1 },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="grid"]' }]
  },

  renderHTML({ node, HTMLAttributes }) {
    const columnClasses = {
      1: 'grid-cols-1',
      2: 'grid-cols-2',
      3: 'grid-cols-3',
      4: 'grid-cols-4',
      5: 'grid-cols-5',
      6: 'grid-cols-6',
    }

    const rowClasses = {
      1: 'grid-rows-1',
      2: 'grid-rows-2',
      3: 'grid-rows-3',
      4: 'grid-rows-4',
      5: 'grid-rows-5',
      6: 'grid-rows-6',
    }

    const colsClass = columnClasses[node.attrs.columns] || 'grid-cols-2'
    const rowsClass = rowClasses[node.attrs.rows] || 'grid-rows-1'

    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'grid',
        class: `grid gap-4 ${colsClass} ${rowsClass}`,
      }),
      0,
    ]
  },

  addCommands() {
    return {
      insertGrid: (columns = 1, rows = 1) => ({ tr, dispatch, editor }) => {
        const { schema } = editor;

        const cells = Array.from({ length: columns * rows }).map(() =>
          schema.nodes.gridCell.create({}, [schema.nodes.paragraph.create()])
        );

        const gridNode = schema.nodes.grid.create(
          { columns, rows },
          cells
        );

        if (dispatch) {
          const offset = tr.selection.from;
          tr.replaceSelectionWith(gridNode)
            .scrollIntoView();

          // Focus first cell
          const firstCellPos = offset + 1;
          tr.setSelection(TextSelection.near(tr.doc.resolve(firstCellPos)));

          dispatch(tr);
        }

        return true;
      },
      addGridRow: () => ({ state, dispatch }) => {
          const { selection, tr, schema } = state;
          const grid = findParentNodeClosestToPos(
            selection.$from,
            node => node.type.name === 'grid'
          );
          if (!grid) return false;

          const { node: gridNode, pos: gridPos } = grid;
          const columns = gridNode.attrs.columns;

          const newCells = Array.from({ length: columns }).map(() =>
            schema.nodes.gridCell.create({}, [schema.nodes.paragraph.create()])
          );

          // Insert new cells at the end of the grid
          let insertPos = gridPos + gridNode.nodeSize - 1; // insert before closing node
          newCells.forEach(cell => {
            tr.insert(insertPos, cell);
            insertPos += cell.nodeSize;
          });

          // Update the rows attribute
          tr.setNodeMarkup(gridPos, undefined, {
            ...gridNode.attrs,
            rows: gridNode.attrs.rows + 1,
          });

          dispatch(tr);
          return true;
        },

      addGridColumn: () => ({ state, dispatch }) => {
            const { selection, tr, schema } = state;
            const grid = findParentNodeClosestToPos(
              selection.$from,
              node => node.type.name === 'grid'
            );
            if (!grid) return false;

            const { node: gridNode, pos: gridPos } = grid;
            const rows = gridNode.attrs.rows;

            const newCells = Array.from({ length: rows }).map(() =>
              schema.nodes.gridCell.create({}, [schema.nodes.paragraph.create()])
            );

            // Insert all new cells at the end of the grid
            let insertPos = gridPos + gridNode.nodeSize - 1; // before closing node
            newCells.forEach(cell => {
              tr.insert(insertPos, cell);
              insertPos += cell.nodeSize;
            });

            // Update columns attribute
            tr.setNodeMarkup(gridPos, undefined, {
              ...gridNode.attrs,
              columns: gridNode.attrs.columns + 1,
            });

            dispatch(tr);
            return true;
          },
      addGridCell: () => ({ state, dispatch }) => {
            const { selection, tr, schema } = state;

            const gridCell = findParentNodeClosestToPos(
              selection.$from,
              node => node.type.name === 'gridCell'
            );
            if (!gridCell) return false;

            const { pos: cellPos } = gridCell;

            const grid = findParentNodeClosestToPos(
              selection.$from,
              node => node.type.name === 'grid'
            );
            if (!grid) return false;

            const { node: gridNode, pos: gridPos } = grid;
            const columns = gridNode.attrs.columns;

            const newCell = schema.nodes.gridCell.create({}, [
              schema.nodes.paragraph.create(),
            ]);

            // Insert it immediately after the current cell
            tr.insert(cellPos + gridCell.node.nodeSize, newCell);

            const totalCells = gridNode.childCount + 1; 
            const newRows = Math.ceil(totalCells / columns);

            // Update grid attributes
            tr.setNodeMarkup(gridPos, undefined, {
              ...gridNode.attrs,
              rows: newRows,
            });

            dispatch(tr);
            return true;
          },
          deleteGrid: () => ({ state, dispatch, tr }) => {
            const grid = findParentNodeClosestToPos(
              state.selection.$from,
              node => node.type.name === 'grid'
            );
            if (!grid) return false;

            const { pos, node } = grid;

            tr.delete(pos, pos + node.nodeSize);

            tr.setSelection(TextSelection.near(tr.doc.resolve(pos)));

            if (dispatch) dispatch(tr);
            return true;
          },
    }
  },
})
