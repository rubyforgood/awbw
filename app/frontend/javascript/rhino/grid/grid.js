import { Node, mergeAttributes, findParentNodeClosestToPos } from '@tiptap/core'

export const Grid = Node.create({
  name: 'grid',
  group: 'block',
  content: 'gridRow+',
  isolating: true,

  addAttributes() {
    return {
      columns: { default: 2 },
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
    const colsClass = columnClasses[node.attrs.columns] || 'grid-cols-2'

    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'grid',
        class: `grid gap-4 ${colsClass}`,
      }),
      0,
    ]
  },

  addCommands() {
    return {
      // Insert a new grid with given rows and columns
      insertGrid:
        (columns = 2, rows = 2) =>
        ({ commands }) => {
          const content = Array.from({ length: rows }).map(() => ({
            type: 'gridRow',
            content: Array.from({ length: columns }).map(() => ({
              type: 'gridCell',
              content: [{ type: 'paragraph' }],
            })),
          }))

          return commands.insertContent({
            type: this.name,
            attrs: { columns },
            content,
          })
        },

      // Add a new row
      addGridRow:
        () =>
        ({ state, commands }) => {
          const { selection } = state
          const grid = findParentNodeClosestToPos(
            selection.$from,
            node => node.type.name === 'grid'
          )
          if (!grid) return false

          const columns = grid.node.attrs.columns
          const newRow = {
            type: 'gridRow',
            content: Array.from({ length: columns }).map(() => ({
              type: 'gridCell',
              content: [{ type: 'paragraph' }],
            })),
          }

          return commands.insertContentAt(grid.pos + grid.node.nodeSize - 1, newRow)
        },

      // Add a new column to all rows
      //


addGridColumn:
  () =>
  ({ state, commands }) => {
    const { selection, schema } = state;
    const gridPos = findParentNodeClosestToPos(
      selection.$from,
      node => node.type.name === 'grid'
    );
    if (!gridPos) return false;

    const { node: gridNode, pos } = gridPos;
    const oldColumns = gridNode.attrs.columns;
    const newColumns = oldColumns + 1;

    // Update columns attribute first
    commands.updateAttributes('grid', { columns: newColumns });

    // Collect all row positions
    const rowPositions = [];
    let offset = 1;
    gridNode.forEach(row => {
      rowPositions.push(pos + offset);
      offset += row.nodeSize;
    });

    // Insert a new cell at the end of each row
    rowPositions.reverse().forEach(rowPos => {
      commands.insertContentAt(
        rowPos + state.doc.nodeAt(rowPos).nodeSize - 1,
        schema.nodes.gridCell.create({}, schema.nodes.paragraph.create())
      );
    });

    return true;
  },

      // Delete grid
      deleteGrid:
        () =>
        ({ state, commands }) => {
          const { selection } = state
          const grid = findParentNodeClosestToPos(
            selection.$from,
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
