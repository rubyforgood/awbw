import { Node, mergeAttributes } from '@tiptap/core'

export const GridRow = Node.create({
  name: 'gridRow',
  content: 'gridCell+',

  parseHTML() {
    return [{ tag: 'div[data-type="grid-row"]' }]
  },

  renderHTML({ HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'grid-row',
        class: 'contents',      // Tailwind sees children directly
        style: 'display: contents;', // fallback in case CSS missing
      }),
      0,
    ]
  },
})
