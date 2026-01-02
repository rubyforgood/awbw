import "./custom-editor.js"
import "./custom-editor.css"
import { Table } from '@tiptap/extension-table'
import { TableCell } from '@tiptap/extension-table-cell'
import { TableHeader } from '@tiptap/extension-table-header'
import { TableRow } from '@tiptap/extension-table-row'
import Youtube from '@tiptap/extension-youtube'
import TextAlign from '@tiptap/extension-text-align'
import { Grid } from './grid/grid'
import { GridCell } from './grid/gridCell'

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
      }),
      Grid,
      GridCell
  )
}

document.addEventListener("rhino-before-initialize", extendRhinoEditor)

