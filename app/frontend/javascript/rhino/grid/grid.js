import { Node, mergeAttributes, findParentNodeClosestToPos } from '@tiptap/core'

// Static mapping for Tailwind classes
const columnClasses = {
  1: 'grid-cols-1',
  2: 'grid-cols-2',
  3: 'grid-cols-3',
  4: 'grid-cols-4',
  5: 'grid-cols-5',
  6: 'grid-cols-6',
}

export const Grid = Node.create({
  name: 'grid',
  group: 'block',
  content: 'gridCell+',
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
    const cols = node.attrs.columns
    const colsClass = columnClasses[cols] || 'grid-cols-2'

    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'grid',
        class: `grid gap-4 ${colsClass}`,
      }),
      0, // render children (gridCell nodes)
    ]
  },

  addCommands() {
    return {
      // Insert a new grid with rows x columns
      insertGrid:
        (columns = 2, rows = 1) =>
        ({ commands }) => {
          const content = Array.from({ length: rows * columns }).map(() => ({
            type: 'gridCell',
            content: [{ type: 'paragraph' }],
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
          const newCells = Array.from({ length: columns }).map(() => ({
            type: 'gridCell',
            content: [{ type: 'paragraph' }],
          }))

          return commands.insertContentAt(
            grid.pos + grid.node.nodeSize - 1,
            newCells
          )
        },

      // Add a new column to all rows
      addGridColumn:
        () =>
        ({ state, tr, commands }) => {
          const { selection, schema } = state
          const grid = findParentNodeClosestToPos(
            selection.$from,
            node => node.type.name === 'grid'
          )
          if (!grid) return false

          const { node, pos } = grid
          const newColumns = node.attrs.columns + 1

          // Update the columns attribute
          tr.setNodeMarkup(pos, undefined, {
            ...node.attrs,
            columns: newColumns,
          })

          // Append one new cell per row
          const totalCells = node.content.size
          const oldColumns = node.attrs.columns
          const rowCount = Math.ceil(totalCells / oldColumns)
          let insertPos = pos + 1

          for (let i = 0; i < rowCount; i++) {
            tr.insert(
              insertPos + i * (oldColumns + 1) + oldColumns,
              schema.nodes.gridCell.create({}, schema.nodes.paragraph.create())
            )
          }

          return commands.editor?.view?.dispatch(tr) || true
        },

      deleteGrid:
            () =>
            ({ state, commands }) => {
              const { selection } = state

              const grid = findParentNodeClosestToPos(
                selection.$from,
                node => node.type.name === 'grid'
              )

              if (!grid) return false

              // Delete the grid node entirely
              return commands.deleteRange({
                from: grid.pos,
                to: grid.pos + grid.node.nodeSize,
              })
        },
    }
  },
})
