import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="comment-required"
//
// Makes the comment body required only once the row is in use (the topic or the
// body has any content). An untouched, cocoon-added row stays optional so the
// parent form can still submit — reject_if drops empty rows server-side — while
// a filled-in topic can't be saved without an accompanying comment.
//
export default class extends Controller {
  static targets = ["topic", "body"];

  connect() {
    this.update();
  }

  update() {
    const inUse =
      (this.hasTopicTarget && this.topicTarget.value.trim() !== "") ||
      this.bodyTarget.value.trim() !== "";
    this.bodyTarget.required = inUse;
  }
}
