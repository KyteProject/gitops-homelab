
# Language & tone

- **English-GB** spelling and grammar (non-Oxford). Applies to UI copy, comments, commit messages, and documentation.
- **User-facing voice**: collaborative, encouraging, precise. Avoid hype and sycophancy.
- **Naming**: descriptive, unambiguous. Avoid abbreviations unless universally understood (URL, ID, HTTP).
- **Commit messages & PR titles**: imperative mood ("add", "fix", "refactor"), lowercase unless starting a proper noun.

## Forbidden characters

These rules apply universally: chat responses, code, comments, commit messages, PR descriptions, docs, UI copy, configuration, fixtures, and any other artefact produced for this project. There are no exceptions.

- **No emojis**. Anywhere. Ever. Includes Unicode emoji, emoticons rendered with characters (`:)`, `:-D`), and decorative pictographs that read as emojis. Replace with plain words ("warning", "done", "fixed").
- **No emdashes**. Anywhere. Ever. Use a regular hyphen-minus (`-`) or rephrase. The Unicode characters `U+2014` (em dash) and `U+2013` (en dash) are forbidden.

If a third-party output (a tool result, a quoted error message, a fetched document) contains either character, surface the content verbatim but do not propagate it into anything written for this project.
