import "./custom-editor.js"
import { Table } from '@tiptap/extension-table'
import { TableCell } from '@tiptap/extension-table-cell'
import { TableHeader } from '@tiptap/extension-table-header'
import { TableRow } from '@tiptap/extension-table-row'
//
// function extendRhinoEditor (event) {
//   const rhinoEditor = event.target
//
//   console.log("Event triggered for:", rhinoEditor)
//   console.log("Rhino Editor properties:", Object.keys(rhinoEditor))
//   if (rhinoEditor == null) return
//   console.log("Extending Rhino editor with Table extensions")  // <-- debug
//   console.log("Current extensions:", rhinoEditor.extensions || [])
//   rhinoEditor.addExtensions(Table)
//   rhinoEditor.addExtensions(TableRow)
//   rhinoEditor.addExtensions(TableHeader)
//   rhinoEditor.addExtensions(TableCell)
//   rhinoEditor.rebuildEditor()
//
//   }
function extendRhinoEditor (event) {
  const rhinoEditor = event.target
  if (rhinoEditor == null) return
  rhinoEditor.addExtensions(Table, TableRow, TableHeader, TableCell)
  // any time addExtensions is called, rebuildEditor should run.
  //
console.log("Current extensions:", rhinoEditor.extensions || [])
}

document.addEventListener("rhino-before-initialize", extendRhinoEditor)
