// app/javascript/rhino-editor/extensions/ActionTextAttachmentMention.js
import Mention from "@tiptap/extension-mention";
import { mergeAttributes } from "@tiptap/core";
import tippy from "tippy.js";
import "../mentions/MentionList";

// https://github.com/KonnorRogers/rhino-editor/pull/111
// import { findAttribute } from "rhino-editor/exports/extensions/find-attribute.js";
function findAttribute(element, attribute) {
  const attr = element
    .closest("action-text-attachment")
    ?.getAttribute(attribute);
  if (attr) return attr;

  const attrs = element
    .closest("[data-trix-attachment]")
    ?.getAttribute("data-trix-attachment");
  if (!attrs) return null;

  return JSON.parse(attrs)[attribute];
}

const ActionTextAttachmentMention = Mention.extend({
  name: "ActiveRecordMention",
  addOptions() {
    return {
      HTMLAttributes: {},
      renderLabel({ options, node }) {
        return `${options.suggestion.char}${node.attrs.label ?? node.attrs.id}`;
      },
      attachmentContentType: "application/octet-stream",
      suggestions: [], // Empty array ensures it falls back to suggestion
      suggestion: {
        render: () => {
          let component;
          let popup;

          return {
            onStart: (props) => {
              component = document.createElement("mention-list");
              component.items = props.items;
              component.command = props.command;

              if (!props.clientRect) {
                return;
              }
              popup = tippy("body", {
                getReferenceClientRect: props.clientRect,
                appendTo: () => document.body,
                content: component,
                showOnCreate: true,
                interactive: true,
                trigger: "manual",
                placement: "bottom-start",
              });
            },

            onUpdate(props) {
              component.items = props.items;
              component.command = props.command;
              if (!props.clientRect) {
                return;
              }

              popup[0].setProps({
                getReferenceClientRect: props.clientRect,
              });
            },

            onKeyDown(props) {
              if (props.event.key === "Escape") {
                popup[0].hide();
                return true;
              }
              return component.onKeyDown(props);
            },

            onExit() {
              popup[0].destroy();
            },
          };
        },
        command: ({ editor, range, props }) => {
          const nodeAfter = editor.view.state.selection.$to.nodeAfter;
          const overrideSpace = nodeAfter?.text?.startsWith(" ");

          if (overrideSpace) {
            range.to += 1;
          }
          editor
            .chain()
            .focus()
            .insertContentAt(range, [
              {
                type: this.name,
                attrs: props,
              },
              {
                type: "text",
                text: " ",
              },
            ])
            .run();

          window.getSelection()?.collapseToEnd();
        },
        allow: ({ state, range }) => {
          const $from = state.doc.resolve(range.from);
          const type = state.schema.nodes[this.name];
          const allow = !!$from.parent.type.contentMatch.matchType(type);

          return allow;
        },
      },
    };
  },
  parseHTML() {
    return [
      {
        tag: `[data-trix-attachment]`,
        getAttrs: (element) => {
          if (
            findAttribute(element, "contentType") ==
            this.options.attachmentContentType
          ) {
            return true;
          }
          return false;
        },
      },
    ];
  },
  addAttributes() {
    return {
      sgid: {
        default: null,
        parseHTML: (element) => {
          return findAttribute(element, "sgid");
        },
        renderHTML: (attributes) => {
          return {};
        },
      },
      content: {
        default: null,
        parseHTML: (element) => {
          const raw = findAttribute(element, "content");
          if (!raw) return null;

          // remove erb comments
          const withoutComments = raw.replace(/<!--[\s\S]*?-->/g, "");

          const div = document.createElement("div");
          div.innerHTML = withoutComments;

          return div.textContent?.replace(/\s+/g, " ").trim() || null;
        },
        renderHTML: () => {
          return {};
        },
      },
      contentType: {
        default: this.options.attachmentContentType,
        parseHTML: (element) => {
          return findAttribute(element, "contentType");
        },
        renderHTML: (attributes) => {
          return {};
        },
      },
    };
  },
  renderHTML({ node, HTMLAttributes }) {
    const trixAttributes = {
      sgid: node.attrs.sgid,
      content: node.attrs.content,
      contentType: node.attrs.contentType,
    };
    const char = this.options.suggestion?.char || "*";
    const label = [
      "span",
      { class: "mention" },
      `${char}${node.attrs.content}`,
    ];
    return [
      "span",
      mergeAttributes(
        { "data-trix-attachment": JSON.stringify(trixAttributes) },
        this.options.HTMLAttributes,
        HTMLAttributes,
      ),
      label,
    ];
  },
});

export default ActionTextAttachmentMention;
