import { Node, mergeAttributes, findParentNodeClosestToPos } from '@tiptap/core'

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
      insertGrid: (columns = 2, rows = 2) => ({ commands }) => {
        const content = Array.from({ length: columns * rows }).map(() => ({
          type: 'gridCell',
          content: [{ type: 'paragraph' }],
        }))

        return commands.insertContent({
          type: this.name,
          attrs: { columns, rows },
          content,
        })
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

          // Create new cells for the row
          const newCells = Array.from({ length: columns }).map(() =>
            schema.nodes.gridCell.create({}, [schema.nodes.paragraph.create()])
          );

          // Insert new cells at the end of the grid
          let insertPos = gridPos + gridNode.nodeSize - 1; // -1 to insert before the closing node
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

            // Create new cells equal to number of rows
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

            // Find the current grid cell
            const gridCell = findParentNodeClosestToPos(
              selection.$from,
              node => node.type.name === 'gridCell'
            );
            if (!gridCell) return false;

            const { pos: cellPos } = gridCell;

            // Find the parent grid
            const grid = findParentNodeClosestToPos(
              selection.$from,
              node => node.type.name === 'grid'
            );
            if (!grid) return false;

            const { node: gridNode, pos: gridPos } = grid;
            const columns = gridNode.attrs.columns;

            // Create a new empty grid cell
            const newCell = schema.nodes.gridCell.create({}, [
              schema.nodes.paragraph.create(),
            ]);

            // Insert it immediately after the current cell
            tr.insert(cellPos + gridCell.node.nodeSize, newCell);

            // Count total cells after insertion
            const totalCells = gridNode.childCount + 1; // +1 for the new cell
            const newRows = Math.ceil(totalCells / columns);

            // Update grid attributes
            tr.setNodeMarkup(gridPos, undefined, {
              ...gridNode.attrs,
              rows: newRows,
            });

            dispatch(tr);
            return true;
          },
      deleteGrid: () => ({ state, commands }) => {
        const grid = findParentNodeClosestToPos(
          state.selection.$from,
          node => node.type.name === 'grid'
        )
        if (!grid) return false

        return commands.deleteRange({
          from: grid.pos,
          to: grid.pos + grid.node.nodeSize,
        })
      },
    }
  },
})
