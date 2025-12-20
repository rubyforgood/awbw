import "./custom-editor.js"
import { Table } from '@tiptap/extension-table'
import { TableCell } from '@tiptap/extension-table-cell'
import { TableHeader } from '@tiptap/extension-table-header'
import { TableRow } from '@tiptap/extension-table-row'
import Youtube from '@tiptap/extension-youtube'
import TextAlign from '@tiptap/extension-text-align'
import { Grid } from './grid/grid'
// import { GridRow } from './grid/gridRow'
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
      // GridRow,
      GridCell
  )
}

document.addEventListener("rhino-before-initialize", extendRhinoEditor)

