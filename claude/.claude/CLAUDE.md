# Code Style

- Never use emojis in code or code comments.
- Only use characters found on a standard keyboard (ASCII) when writing code and code comments. No smart quotes, em dashes, arrows, box-drawing characters, or other non-ASCII symbols.
- Never use relative imports. Always use absolute imports (e.g. `from package.module import X`, not `from ..module import X` or `from . import X`). Relative imports compile but are not robust.
