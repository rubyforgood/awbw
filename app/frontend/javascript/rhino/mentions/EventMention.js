import ActionTextAttachmentMention from "./ActionTextAttachmentMention";
import { PluginKey } from "@tiptap/pm/state";
import Suggestion from "@tiptap/suggestion";

const EventMention = ActionTextAttachmentMention.extend({
  name: "EventMention",
  addProseMirrorPlugins() {
    return [
      Suggestion({
        editor: this.editor,
        pluginKey: new PluginKey("EventMentionSuggestion"),
        ...this.options.suggestion,
      }),
    ];
  },
});

export default EventMention;
