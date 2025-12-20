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
        class: 'contents', // display: contents so cells are direct grid items
        style: 'display: contents;',
      }),
      0,
    ]
  },
})
