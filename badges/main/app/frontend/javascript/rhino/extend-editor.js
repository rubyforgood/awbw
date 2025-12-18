import "./custom-editor.js"
import { Table } from '@tiptap/extension-table'
import { TableCell } from '@tiptap/extension-table-cell'
import { TableHeader } from '@tiptap/extension-table-header'
import { TableRow } from '@tiptap/extension-table-row'
import Youtube from '@tiptap/extension-youtube'
import TextAlign from '@tiptap/extension-text-align'

function extendRhinoEditor(event) {
  const rhinoEditor = event.target
  if (!rhinoEditor) return

  rhinoEditor.addExtensions(
      Table,
      TableRow,
      TableHeader,
      TableCell,
      Youtube.configure({ nocookie: true }),
      TextAlign.configure({
        types: ['heading', 'paragraph'],
      })
  )
}

document.addEventListener("rhino-before-initialize", extendRhinoEditor)

