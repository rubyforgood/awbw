# Deduplication UI Screenshots (Text Representation)

## 1. Categories Dedupe Index Page

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  Dedupe Categories                                                  │
│                                                                     │
│  [ 🔗 Possible dupes ]  [ 🏷️  Categories ]                         │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ [Purple Background]                                         │  │
│  │                                                             │  │
│  │  Category to delete          Category to keep              │  │
│  │  [-- category to delete --▼] [-- category to keep --▼]     │  │
│  │                                                             │  │
│  │     [ Preview this dedupe ]     [ Clear ]                  │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  Possible Duplicate Groups (2)                                      │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ "child abuse" (2 categories)                                │  │
│  │ • Child Abuse (ID: 5, Type: Focus Area, Published,         │  │
│  │               15 taggings)                                   │  │
│  │ • child abuse (ID: 12, Type: Focus Area, Unpublished,      │  │
│  │               3 taggings)                                    │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ "domestic violence" (2 categories)                          │  │
│  │ • Domestic Violence (ID: 7, Type: Focus Area, Published,   │  │
│  │                     22 taggings)                            │  │
│  │ • DOMESTIC VIOLENCE (ID: 18, Type: Focus Area,             │  │
│  │                     Unpublished, 1 tagging)                 │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 2. Categories Dedupe Preview Page

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Preview Category Deduplication                                      │
│  Review the differences before merging. The category on the left     │
│  will be DELETED and its associations will be moved to the right.    │
│                                                                      │
│  ← Back to Dedupe                                                    │
│                                                                      │
│ ┌──────────────────────────┐  ┌──────────────────────────┐         │
│ │ [RED BORDER]             │  │ [GREEN BORDER]           │         │
│ │ 🗑️  Category to DELETE   │  │ ✓ Category to KEEP       │         │
│ │                          │  │                          │         │
│ │ ID: 12                   │  │ ID: 5                    │         │
│ │ Name: child abuse        │  │ Name: Child Abuse        │         │
│ │ Type: Focus Area         │  │ Type: Focus Area         │         │
│ │ Published: No [DIFF]     │  │ Published: Yes           │         │
│ │ Position: 5 [DIFF]       │  │ Position: 3              │         │
│ │ Created: 2024-03-15      │  │ Created: 2024-01-10      │         │
│ │ Associated: 3            │  │ Associated: 15           │         │
│ │                          │  │                          │         │
│ │ Tagged Items:            │  │ Tagged Items:            │         │
│ │ • Workshop: Art Therapy  │  │ • Workshop: Art Therapy  │         │
│ │ • Workshop: Music        │  │ • Workshop: Music        │         │
│ │ • Workshop: Drama        │  │ • Workshop: Drama        │         │
│ │ ...                      │  │ ...                      │         │
│ └──────────────────────────┘  └──────────────────────────┘         │
│                                                                      │
│ ⚠️  Warning: This action cannot be undone. The category             │
│    "child abuse" (ID: 12) will be permanently deleted, and all      │
│    its 3 associations will be moved to "Child Abuse" (ID: 5).       │
│                                                                      │
│              [ Execute Merge ]  [ Cancel ]                           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## 3. Sectors Dedupe Index Page

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  Dedupe Sectors                                                     │
│                                                                     │
│  [ 🔗 Possible dupes ]  [ 🏷️  Sectors ]                            │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ [Purple Background]                                         │  │
│  │                                                             │  │
│  │  Sector to delete            Sector to keep                │  │
│  │  [-- sector to delete --▼]   [-- sector to keep --▼]       │  │
│  │                                                             │  │
│  │     [ Preview this dedupe ]     [ Clear ]                  │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  Possible Duplicate Groups (1)                                      │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ "sexual assault" (2 sectors)                                │  │
│  │ • Sexual Assault (ID: 3, Published, 28 taggings)            │  │
│  │ • sexual assault (ID: 9, Unpublished, 2 taggings)           │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Color Legend

- **Purple (#7C3AED)**: Primary action areas, active tab
- **Red (#DC2626)**: Delete/danger actions, items being removed
- **Green (#16A34A)**: Keep/success actions, items being kept
- **Yellow (#F59E0B)**: Warnings, differences between records
- **Gray**: Neutral actions, cancel buttons, inactive states

## Icons Used

- 🗑️  Trash can - Delete action
- ✓  Check mark - Keep action
- 🔗 Link slash - Possible duplicates tab
- 🏷️  Tags - Main index tab
- ⚠️  Warning triangle - Caution messages
- ← Arrow - Back navigation
