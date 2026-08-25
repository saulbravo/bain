"""Reader for the RTF fragments e-Sword stores in its modules.

Both Bibles and dictionaries keep their text as RTF rather than plain strings,
and the interesting parts (Strong's numbers, footnote markers, Hebrew and Greek
words) live inside nested groups, so the text has to be walked rather than
scrubbed with regexes.

Non-Latin words are stored as bytes in a legacy code page selected by the font,
which is why runs are decoded per font instead of all at once.
"""

import re

CONTROL = re.compile(r"\\'([0-9a-fA-F]{2})|\\([a-zA-Z]+)(-?\d+)?[ ]?|\\([^a-zA-Z])")

SYMBOLS = {
    "ldblquote": "\u201c",
    "rdblquote": "\u201d",
    "lquote": "\u2018",
    "rquote": "\u2019",
    "emdash": "\u2014",
    "endash": "\u2013",
    "bullet": "",
}

BREAKS = {"par", "line", "PAR"}
SPACES = {"tab", "emspace", "enspace"}


def tokenize(text):
    """Split an RTF fragment into a tree of text, control words and groups."""
    root = []
    stack = [root]
    index = 0
    length = len(text)
    while index < length:
        char = text[index]
        if char == "{":
            group = []
            stack[-1].append(("group", group))
            stack.append(group)
            index += 1
        elif char == "}":
            if len(stack) > 1:
                stack.pop()
            index += 1
        elif char == "\\":
            match = CONTROL.match(text, index)
            if not match:
                index += 1
                continue
            if match.group(1) is not None:
                stack[-1].append(("byte", int(match.group(1), 16)))
            elif match.group(2) is not None:
                stack[-1].append(("ctrl", match.group(2), match.group(3)))
            else:
                stack[-1].append(("text", match.group(4)))
            index = match.end()
        else:
            end = index
            while end < length and text[end] not in "{}\\":
                end += 1
            stack[-1].append(("text", text[index:end]))
            index = end
    return root


class Renderer:
    """Turns the tree into text.

    ``font_codepage`` maps an ``\\fN`` parameter to the code page its bytes are
    in. ``on_group`` receives each finished group with the formatting that was in
    effect inside it, and returns what the group should contribute.
    """

    def __init__(self, font_codepage=None, on_group=None, codepage="cp1252"):
        self.font_codepage = font_codepage or (lambda param: codepage)
        self.on_group = on_group or (lambda text, state: text)
        self.codepage = codepage

    def render(self, raw):
        if raw is None:
            return ""
        if isinstance(raw, bytes):
            raw = raw.decode(self.codepage, "replace")
        text, _ = self._run(tokenize(raw), {"codepage": self.codepage})
        return text

    def _run(self, nodes, state):
        parts = []
        pending = bytearray()
        pending_codepage = state["codepage"]
        local = dict(state)
        skip_fallback = False

        def flush():
            nonlocal pending
            if pending:
                parts.append(pending.decode(pending_codepage, "replace"))
                pending = bytearray()

        for node in nodes:
            kind = node[0]
            if kind == "text":
                text = node[1]
                if skip_fallback:
                    text = text[1:]
                    skip_fallback = False
                if local["codepage"] != self.codepage:
                    # A run in a legacy font holds its word as bytes, some of
                    # which survived as characters rather than \'xx escapes.
                    if pending and pending_codepage != local["codepage"]:
                        flush()
                    pending_codepage = local["codepage"]
                    pending.extend(text.encode(self.codepage, "replace"))
                else:
                    flush()
                    parts.append(text)
            elif kind == "byte":
                if pending and pending_codepage != local["codepage"]:
                    flush()
                pending_codepage = local["codepage"]
                pending.append(node[1])
            elif kind == "ctrl":
                word, param = node[1], node[2]
                if word == "u" and param is not None:
                    # \uN? carries the code point plus an ANSI fallback to drop.
                    flush()
                    code = int(param)
                    parts.append(chr(code + 65536 if code < 0 else code))
                    skip_fallback = True
                    continue
                flush()
                if word in SYMBOLS:
                    parts.append(SYMBOLS[word])
                elif word in BREAKS:
                    parts.append("<br>")
                elif word in SPACES:
                    parts.append(" ")
                elif word == "super":
                    local["super"] = True
                elif word == "i":
                    local["italic"] = param != "0"
                elif word == "b":
                    local["bold"] = param != "0"
                elif word == "ul":
                    local["underline"] = param != "0"
                elif word == "f":
                    local["codepage"] = self.font_codepage(param)
                elif word == "cf":
                    local["color"] = param or "0"
            else:
                flush()
                inherited = dict(local)
                for key in ("super", "italic", "bold", "underline"):
                    inherited[key] = False
                text, inner = self._run(node[1], inherited)
                parts.append(self.on_group(text, inner))

        flush()
        return "".join(parts), local
