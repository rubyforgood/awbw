import { Node, mergeAttributes } from '@tiptap/core'

export const GridCell = Node.create({
  name: 'gridCell',
  content: 'block+',
  parseHTML() {
    return [{ tag: 'div[data-type="grid-cell"]' }]
  },
  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'grid-cell',
        class: 'border border-gray-300 p-3 rounded',
      }),
      0,
    ]
  },
})
