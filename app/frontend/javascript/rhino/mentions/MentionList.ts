// This mention list takes an array of suggested
// items that represent action text attachments
// with the properties of content/contentType/sgid
// and renders a tippy popover that the user can
// navigate and select.
//
// Selecting an item calls the command function
// and passes those three properties back.

import { html, css, LitElement } from "lit";
import { customElement } from "lit/decorators/custom-element.js";
import { property } from "lit/decorators/property.js";

@customElement("mention-list")
class MentionList extends LitElement {
  @property({ type: Array }) items = [];
  @property({ type: Number }) selectedIndex = 0;
  @property({ type: Function }) command;

  static styles = css`
    .suggested-items {
      padding: 0.2rem;
      position: relative;
      border-radius: 0.5rem;
      background: #fff;
      color: rgba(0, 0, 0, 0.8);
      overflow: hidden;
      font-size: 0.9rem;
      box-shadow:
        0 0 0 1px rgba(0, 0, 0, 0.05),
        0px 10px 20px rgba(0, 0, 0, 0.1);
    }
    .suggested-item {
      display: block;
      margin: 0;
      width: 100%;
      text-align: left;
      background: transparent;
      border-radius: 0.4rem;
      border: 1px solid transparent;
      padding: 0.2rem 0.4rem;
    }
    .suggested-item.is-selected {
      border-color: #000;
    }
  `;

  render() {
    return html`
      <div class="suggested-items">
        ${this.items.length > 0
          ? this.items.map(
              (item, index) =>
                html` <button
                  class="suggested-item ${index === this.selectedIndex
                    ? "is-selected"
                    : ""}"
                  @click=${() => this.selectItem(index)}
                >
                  ${item.content}
                </button>`,
            )
          : html`<div class="suggested-item">No result</div>`}
      </div>
    `;
  }

  onKeyDown({ event }) {
    if (event.key === "ArrowUp") {
      this.upHandler();
      return true;
    }

    if (event.key === "ArrowDown") {
      this.downHandler();
      return true;
    }

    if (event.key === "Enter") {
      this.enterHandler();
      return true;
    }

    return false;
  }

  upHandler() {
    this.selectedIndex =
      (this.selectedIndex + this.items.length - 1) % this.items.length;
  }

  downHandler() {
    this.selectedIndex = (this.selectedIndex + 1) % this.items.length;
  }

  enterHandler() {
    this.selectItem(this.selectedIndex);
  }

  selectItem(index) {
    const item = this.items[index];
    if (item) {
      this.command({
        sgid: item.sgid,
        content: item.content,
        contentType: item.contentType,
      });
    }
  }
}

export default MentionList;
