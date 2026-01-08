// This custom editor
// extends the default tiptap editor to have a toolbar
// with table editing buttons in it.

import { html } from "lit";
import "rhino-editor/exports/styles/trix.css";
import { TipTapEditor } from "rhino-editor/exports/elements/tip-tap-editor.js";
import * as table_icons from "./table-icons.js";
import * as table_translations from "./table-translations.js";
import * as grid_icons from "./grid/grid-icons.js";
import * as align_icons from "./align-icons.js";
import { application } from "../controllers/application";
import { renderGridMenu } from "./grid/grid-menu.js";

class CustomEditor extends TipTapEditor {
  renderToolbar() {
    if (this.readonly) return html``;

    return html`
      <slot name="toolbar">
        <role-toolbar class="toolbar" part="toolbar" role="toolbar">
          <slot name="toolbar-start">${this.renderToolbarStart()}</slot>

          <!-- Bold -->
          <slot name="before-bold-button"></slot>
          <slot name="bold-button">${this.renderBoldButton()}</slot>
          <slot name="after-bold-button"></slot>

          <!-- Italic -->
          <slot name="before-italic-button"></slot>
          <slot name="italic-button">${this.renderItalicButton()}</slot>
          <slot name="after-italic-button"></slot>

          <!-- Strike -->
          <slot name="before-strike-button"></slot>
          <slot name="strike-button">${this.renderStrikeButton()}</slot>
          <slot name="after-strike-button"></slot>

          <!-- Link -->
          <slot name="before-link-button"></slot>
          <slot name="link-button">${this.renderLinkButton()}</slot>
          <slot name="after-link-button"></slot>

          <!-- <Text Alignment> -->
          <slot name="align-buttons">${this.renderAlignmentButtons()}</slot>

          <!-- Heading -->
          <slot name="before-heading-button"></slot>
          <slot name="heading-button">${this.renderHeadingButton()}</slot>
          <slot name="after-heading-button"></slot>

          <slot name="hr-button">${this.renderHorizontalRuleButton()}</slot>

          <!-- Blockquote -->
          <slot name="before-blockquote-button"></slot>
          <slot name="blockquote-button">${this.renderBlockquoteButton()}</slot>
          <slot name="after-blockquote-button"></slot>

          <!-- Code block -->
          <slot name="before-code-block-button"></slot>
          <slot name="code-block-button">${this.renderCodeBlockButton()}</slot>
          <slot name="after-code-block-button"></slot>

          <!-- Bullet List -->
          <slot name="before-bullet-list-button"></slot>
          <slot name="bullet-list-button"
            >${this.renderBulletListButton()}</slot
          >
          <slot name="after-bullet-list-button"></slot>

          <!-- Ordered list -->
          <slot name="before-ordered-list-button"></slot>
          <slot name="ordered-list-button">
            ${this.renderOrderedListButton()}
          </slot>
          <slot name="after-ordered-list-button"></slot>

          <slot name="before-decrease-indentation-button"></slot>
          <slot name="decrease-indentation-button"
            >${this.renderDecreaseIndentation()}</slot
          >
          <slot name="after-decrease-indentation-button"></slot>

          <slot name="before-increase-indentation-button"></slot>
          <slot name="increase-indentation-button"
            >${this.renderIncreaseIndentation()}</slot
          >

          <slot name="after-increase-indentation-button"></slot>

          <slot name="grid-button">${this.renderGridButton()}</slot>
          <slot name="table-button"> ${this.renderTableButton()} </slot>
          <!-- Attachments -->
          <slot name="before-attach-files-button"></slot>
          <slot name="attach-files-button"
            >${this.renderAttachmentButton()}</slot
          >
          <slot name="after-attach-files-button"></slot>
          <!-- Source Modal button -->

          <!-- Undo -->
          <slot name="before-undo-button"></slot>

          <slot name="undo-button"> ${this.renderUndoButton()} </slot>
          <slot name="after-undo-button"></slot>

          <!-- Redo -->
          <slot name="before-redo-button"></slot>
          <slot name="redo-button"> ${this.renderRedoButton()} </slot>

          <slot name="after-redo-button"></slot>

          <slot name="source-modal-button">
            <button
              class="toolbar__button rhino-toolbar-button"
              type="button"
              @click=${() => {
                const modalController =
                  application.getControllerForElementAndIdentifier(
                    document.querySelector("[data-controller='rhino-source']"),
                    "rhino-source",
                  );
                if (modalController) {
                  modalController.registerEditor(this.editor);
                  modalController.show();
                }
              }}
            >
              <role-tooltip
                hoist
                part="toolbar-tooltip"
                exportparts=${this.__tooltipExportParts}
              >
                Edit HTML
              </role-tooltip>
              &lt;/&gt;
            </button>
          </slot>

          <slot name="toolbar-end">${this.renderToolbarEnd()}</slot>
        </role-toolbar>

        ${this.renderTableMenu()} ${renderGridMenu(this.editor)}
        ${this.renderBubbleMenuToolbar()}
        ${this.renderLinkDialogAnchoredRegion()}
      </slot>
    `;
  }

  renderGridButton() {
    return html`
      <button
        type="button"
        class="toolbar__button rhino-toolbar-button"
        title="Insert grid"
        @click="${(event) => {
          this.editor.chain().focus().insertGrid().run();
        }}"
      >
        <slot name="table-tooltip">
          <role-tooltip
            id="table"
            hoist
            part="toolbar-tooltip toolbar-tooltip__table"
            exportparts=${this.__tooltipExportParts}
          >
            ${table_translations.insertTable}
          </role-tooltip>
        </slot>
        <slot name="table-icon">${grid_icons.insertGrid}</slot>
      </button>
    `;
  }

  renderHorizontalRuleButton() {
    return html`
      <button
        class="toolbar__button rhino-toolbar-button"
        type="button"
        aria-describedby="horizontal rule"
        data-role="toolbar-item"
        @click="${(event) => {
          this.editor.chain().focus().setHorizontalRule().run();
        }}"
      >
        <slot name="table-tooltip">
          <role-tooltip
            id="horiztaon-rule"
            hoist
            part="toolbar-tooltip toolbar-tooltip__table"
            exportparts=${this.__tooltipExportParts}
          >
            Horizontal Rule
          </role-tooltip>
        </slot>
        <slot name="table-icon">---</slot>
      </button>
    `;
  }
  renderTableButton() {
    const tableEnabled = true; // Boolean(this.editor?.commands.setAttachment);

    if (!tableEnabled) return html``;

    const isDisabled = this.editor == null;
    return html`
      <button
        class="toolbar__button rhino-toolbar-button"
        type="button"
        aria-describedby="table"
        aria-disabled=${isDisabled}
        data-role="toolbar-item"
        @click=${function (e) {
          this.editor
            .chain()
            .focus()
            .insertTable({ rows: 3, cols: 3, withHeaderRow: true })
            .run();
        }}
      >
        <slot name="table-tooltip">
          <role-tooltip
            id="table"
            hoist
            part="toolbar-tooltip toolbar-tooltip__table"
            exportparts=${this.__tooltipExportParts}
          >
            ${table_translations.insertTable}
          </role-tooltip>
        </slot>
        <slot name="table-icon">${table_icons.insertTable}</slot>
      </button>
    `;
  }
  renderTableMenu() {
    if (!this.editor || !this.editor.isActive("table")) {
      return html``;
    }
    return html`
      <role-toolbar class="toolbar" part="toolbar" role="toolbar">
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().deleteTable().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.deleteTable}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.deleteTable}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().addColumnBefore().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.addColumnBefore}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.addColumnBefore}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().addColumnAfter().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.addColumnAfter}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.addColumnAfter}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().deleteColumn().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.deleteColumn}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.deleteColumn}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().addRowBefore().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.addRowBefore}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.addRowBefore}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().addRowAfter().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.addRowAfter}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.addRowAfter}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().deleteRow().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.deleteRow}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.deleteRow}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().mergeOrSplit().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.mergeOrSplit}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.mergeOrSplit}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().toggleHeaderRow().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.toggleHeaderRow}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.toggleHeaderRow}</slot>
        </button>
        <button
          class="toolbar__button rhino-toolbar-button"
          type="button"
          aria-describedby="table"
          aria-disabled="false"
          data-role="toolbar-item"
          @click=${function (e) {
            this.editor.chain().focus().toggleHeaderColumn().run();
          }}
        >
          <slot name="table-tooltip">
            <role-tooltip
              id="table"
              hoist
              part="toolbar-tooltip toolbar-tooltip__table"
              exportparts=${this.__tooltipExportParts}
            >
              ${table_translations.toggleHeaderColumn}
            </role-tooltip>
          </slot>
          <slot name="table-icon">${table_icons.toggleHeaderColumn}</slot>
        </button>
      </role-toolbar>
    `;
  }

  renderAlignmentButtons() {
    if (!this.editor) return html``;

    const alignmentOptions = [
      { name: "left", icon: align_icons.alignLeft },
      { name: "center", icon: align_icons.alignCenter },
      { name: "right", icon: align_icons.alignRight },
      {
        name: "justify",
        icon: align_icons.alignJustify,
        style: "margin-inline-end:1rem;",
      },
    ];

    const canAlign = ["paragraph", "heading"].some((type) =>
      this.editor.isActive(type),
    );
    if (!canAlign) return html``;

    return html`
      ${alignmentOptions.map(
        (align) => html`
          <button
            class="toolbar__button rhino-toolbar-button"
            type="button"
            style=${align.style || ""}
            aria-disabled=${!this.editor}
            @click=${() =>
              this.editor.chain().focus().setTextAlign(align.name).run()}
          >
            ${align.icon}
          </button>
        `,
      )}
    `;
  }
}

CustomEditor.define("custom-rhino-editor");
