import { Node, mergeAttributes } from '@tiptap/core'

export const GridRow = Node.create({
  name: 'gridRow',
  group: 'block',
  content: 'gridCell+',
  isolating: true,

  parseHTML() {
    return [{ tag: 'div[data-type="grid-row"]' }]
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'grid-row',
        class: 'contents', // allows Tailwind grid to manage layout
      }),
      0,
    ]
  },
})
