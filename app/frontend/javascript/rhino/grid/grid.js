import { Node, mergeAttributes, findParentNodeClosestToPos } from '@tiptap/core'

export const Grid = Node.create({
  name: 'grid',
  group: 'block',
  content: 'gridRow+',
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
            attrs: { columns, rows },
            content,
          })
        },

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

          commands.updateAttributes('grid', { rows: grid.node.attrs.rows + 1 })
          return commands.insertContentAt(grid.pos + grid.node.nodeSize - 1, newRow)
        },

      addGridColumn:
        () =>
        ({ state, commands }) => {
          const { selection } = state
          const grid = findParentNodeClosestToPos(
            selection.$from,
            node => node.type.name === 'grid'
          )
          if (!grid) return false

          const newColumns = grid.node.attrs.columns + 1
          commands.updateAttributes('grid', { columns: newColumns })

          grid.node.forEach((row, offset) => {
            const rowPos = grid.pos + 1 + offset
            commands.insertContentAt(
              rowPos + row.nodeSize - 1,
              state.schema.nodes.gridCell.create({}, state.schema.nodes.paragraph.create())
            )
          })

          return true
        },

      addGridCell:
        () =>
        ({ state, commands }) => {
          const { selection } = state
          const cell = findParentNodeClosestToPos(
            selection.$from,
            node => node.type.name === 'gridCell'
          )
          if (!cell) return false

          return commands.insertContentAt(
            cell.pos + cell.node.nodeSize,
            state.schema.nodes.gridCell.create({}, state.schema.nodes.paragraph.create())
          )
        },

      deleteGrid: () => ({ state, commands }) => {
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
