import ActionTextAttachmentMention from "./ActionTextAttachmentMention";
import { PluginKey } from "@tiptap/pm/state";
import Suggestion from "@tiptap/suggestion";

// When using multiple mention extensions at the same time
// you must make two things unique:
// * The name of the extension
// * The pluginKey for the Suggestion plugin
//
// We do that here.
// Everything else is configured at a higher level.

const WorkshopMention = ActionTextAttachmentMention.extend({
  name: "WorkshopMention",
  addProseMirrorPlugins() {
    return [
      Suggestion({
        editor: this.editor,
        pluginKey: new PluginKey("WorkshopMentionSuggestion"),
        ...this.options.suggestion,
      }),
    ];
  },
});

export default WorkshopMention;
