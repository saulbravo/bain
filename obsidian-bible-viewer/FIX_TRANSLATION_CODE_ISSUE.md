# Fix: Translation Code Not Being Sent in postMessage

## Problem

When copying verses from the Bible app to Obsidian, the translation code (YLT, KJV, etc.) was not being included in the message sent via `postMessage`. The plugin was receiving only `type` and `verses` properties, causing it to default to "BBE" instead of using the actual translation code.

## Root Cause

The issue was with how JavaScript's `postMessage` API serializes objects. When you pass an object to `postMessage`, it uses the [structured clone algorithm](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm) to serialize the data. However, if the object contains:

1. **Non-serializable properties** (functions, symbols, etc.)
2. **Properties that are undefined or null** (may be stripped in some cases)
3. **Complex object references** that can't be cloned
4. **Observable/reactive properties** (like those from Imba's reactive system)

These properties can be lost during serialization.

In our case, the `messageData` object was being created with properties from Imba's reactive system (`me.translation`, `me.book`, etc.), which may not have been properly serialized as plain values.

## Solution

The fix involved explicitly constructing a plain JavaScript object with all properties as primitive types (String, Number, Array) before sending:

### Before (Not Working):
```imba
let messageData = {
    type: 'bible-verse-selection',
    verses: selectedVerses,
    translation: me.translation,  # Could be reactive/observable
    book: me.nameOfCurrentBook,   # Could be reactive/observable
    chapter: me.chapter,          # Could be reactive/observable
    bookId: me.book               # Could be reactive/observable
}
window.parent.postMessage(messageData, '*')
```

### After (Working):
```imba
# Extract values first to ensure they're primitives
let translationCode = me.translation || ''
let bookName = me.nameOfCurrentBook || ''
let chapterNum = me.chapter || 1
let bookIdNum = me.book || 1

# Create a plain object with explicit primitive types
let messageToSend = {
    type: String(messageData.type),
    verses: Array.from(messageData.verses),
    translation: String(messageData.translation),
    book: String(messageData.book),
    chapter: Number(messageData.chapter),
    bookId: Number(messageData.bookId)
}

window.parent.postMessage(messageToSend, '*')
```

## Key Changes Made

### 1. In `imba/src/ui/chapter.imba`:

**Lines 170-173**: Extract values to local variables first:
```imba
let translationCode = me.translation || ''
let bookName = me.nameOfCurrentBook || ''
let chapterNum = me.chapter || 1
let bookIdNum = me.book || 1
```

**Lines 182-189**: Create initial messageData object:
```imba
let messageData = {
    type: 'bible-verse-selection',
    verses: selectedVerses,
    translation: translationCode,
    book: bookName,
    chapter: chapterNum,
    bookId: bookIdNum
}
```

**Lines 199-210**: Create a plain object with explicit types before sending:
```imba
let messageToSend = {
    type: String(messageData.type),
    verses: Array.from(messageData.verses),
    translation: String(messageData.translation),
    book: String(messageData.book),
    chapter: Number(messageData.chapter),
    bookId: Number(messageData.bookId)
}
window.parent.postMessage(messageToSend, '*')
```

### 2. In `obsidian/Bible/.obsidian/plugins/bible-viewer/main.ts`:

**Lines 263-273**: Updated function signature to accept translation and other fields:
```typescript
copyVersesToNote(data: {
    verses: Array<{...}>;
    translation?: string;
    book?: string;
    chapter?: number;
    bookId?: number | string;
})
```

**Lines 310-312**: Use translation code from data:
```typescript
const translationCode = data?.translation || "BBE";
```

**Lines 327-332**: Format as callout with translation code:
```typescript
const calloutHeader = `> [!bible] [${referenceText} - ${translationCode}](${url})`;
```

## Why This Works

1. **Explicit Type Conversion**: By using `String()`, `Number()`, and `Array.from()`, we ensure all properties are plain JavaScript primitives that can be reliably serialized.

2. **No Reactive Dependencies**: By extracting values to local variables first, we break any reactive dependencies that might interfere with serialization.

3. **Clean Object Structure**: Creating a new plain object ensures there are no hidden properties, getters, setters, or prototype chain issues that could cause serialization problems.

4. **Fallback Values**: Using `|| ''` and `|| 1` ensures we always have valid primitive values, never `undefined` or `null`.

## Testing

To verify the fix works:

1. Open Obsidian with the Bible Viewer plugin
2. Navigate to any verse in the Bible app (make sure you're using a translation like YLT, KJV, etc.)
3. Enable verse copy select mode
4. Select a verse and click the chevron button
5. Check the Obsidian Developer Console - you should see:
   - "Preparing message - Translation: YLT" (or your current translation)
   - "About to send messageToSend:" with all properties including translation
   - "Bible Viewer: Full data object received:" should show all fields
6. The verse should be inserted with the correct translation code in the callout

## Related Files Modified

- `imba/src/ui/chapter.imba` - Fixed message sending
- `obsidian/Bible/.obsidian/plugins/bible-viewer/main.ts` - Updated to use translation code
- `obsidian/Bible/.obsidian/plugins/bible-viewer/styles.css` - Added callout styling

## Lessons Learned

1. **postMessage Serialization**: Always ensure objects passed to `postMessage` contain only serializable primitives
2. **Reactive Systems**: When working with reactive frameworks (like Imba), extract values to plain variables before serialization
3. **Type Safety**: Explicitly convert to primitives (String, Number, Array) to ensure proper serialization
4. **Debugging**: Use `JSON.stringify()` to verify what's actually being sent before calling `postMessage`

## Future Considerations

If similar issues occur in the future:
- Check if properties are reactive/observable and extract them first
- Use `JSON.parse(JSON.stringify())` as a fallback to create a clean copy
- Always verify the received data structure matches what was sent
- Add comprehensive logging to track data flow through postMessage

