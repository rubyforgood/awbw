import { Node, mergeAttributes, findParentNodeClosestToPos } from '@tiptap/core'
import { TextSelection } from '@tiptap/pm/state'

export const GridCell = Node.create({
  name: 'gridCell',
  group: 'block',
  content: 'block+',
  isolating: true,

  addAttributes() {
    return {
      verticalAlign: {
        default: 'top', // default alignment
        parseHTML: element => element.dataset.verticalAlign || 'top',
        renderHTML: attributes => {
          const alignClasses = {
            top: 'justify-start',
            center: 'justify-center',
            bottom: 'justify-end',
          }

          return {
            'data-vertical-align': attributes.verticalAlign,
            class: alignClasses[attributes.verticalAlign] || 'justify-start',
          }
        },
      },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="grid-cell"]' }]
  },

  renderHTML({ node, HTMLAttributes }) {
    const alignClasses = {
      top: 'justify-start',
      center: 'justify-center',
      bottom: 'justify-end',
    }

    return [
      'div',
      mergeAttributes(HTMLAttributes, {
        'data-type': 'grid-cell',
        class: `border border-gray-300 p-3 rounded flex flex-col ${alignClasses[node.attrs.verticalAlign]}`,
      }),
      0,
    ]
  },

  addCommands() {
    return {
      setVerticalAlign: alignment => ({ state, dispatch }) => {
        const { selection, tr } = state
        const gridCell = findParentNodeClosestToPos(
          selection.$from,
          node => node.type.name === 'gridCell'
        )
        if (!gridCell) return false

        const { pos, node } = gridCell

        tr.setNodeMarkup(pos, undefined, {
          ...node.attrs,
          verticalAlign: alignment,
        })

        dispatch(tr)
        return true
      },
    }
  },
})
