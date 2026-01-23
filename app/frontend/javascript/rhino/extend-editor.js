import "./custom-editor.js";
import "./custom-editor.css";
import { Table } from "@tiptap/extension-table";
import { TableCell } from "@tiptap/extension-table-cell";
import { TableHeader } from "@tiptap/extension-table-header";
import { TableRow } from "@tiptap/extension-table-row";
import Youtube from "@tiptap/extension-youtube";
import TextAlign from "@tiptap/extension-text-align";
import { Grid } from "./grid/grid";
import { GridCell } from "./grid/gridCell";
import WorkshopMention from "./mentions/WorkshopMention.js";
import ResourceMention from "./mentions/ResourceMention.js";
import AssetMention from "./mentions/AssetMention.js";

function extendRhinoEditor(event) {
  const rhinoEditor = event.target;
  if (!rhinoEditor) return;

  const modelSgid = rhinoEditor.dataset.modelSgid;

  rhinoEditor.addExtensions(
    Table,
    TableRow,
    TableHeader,
    TableCell,
    Youtube.configure({ nocookie: true }),
    TextAlign.configure({
      types: ["heading", "paragraph"],
    }),
    Grid,
    GridCell,
    WorkshopMention.configure({
      suggestion: {
        char: "@",
        items: async ({ query }) => {
          const response = await fetch(
            `/workshop_mentions.json?query=${query}`,
          );
          const data = await response.json();
          return data;
        },
      },

      attachmentContentType: "application/vnd.active_record.workshop",
    }),
    ResourceMention.configure({
      suggestion: {
        char: "#",
        items: async ({ query }) => {
          const response = await fetch(
            `/resource_mentions.json?query=${query}`,
          );
          const data = await response.json();
          return data;
        },
      },

      attachmentContentType: "application/vnd.active_record.resource",
    }),
    AssetMention.configure({
      suggestion: {
        char: "!",
        items: async ({ query }) => {
          const response = await fetch(
            `/rich_text_asset_mentions.json?query=${query}&sgid=${modelSgid}`,
          );
          const data = await response.json();
          return data;
        },
      },

      attachmentContentType: "application/vnd.active_record.asset",
    }),
  );
}

document.addEventListener("rhino-before-initialize", extendRhinoEditor);
