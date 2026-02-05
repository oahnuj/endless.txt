# endless.txt

A minimalist, distraction-free, instant thought capture app that lives in your menu bar. One global hotkey, one text file, infinite space for ideas.

Inspired by [Jeff Huang's productivity text file](https://jeffhuang.com/productivity_text_file/).

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Instant capture** - Global hotkey (⌘+Shift+Space) opens overlay in <200ms
- **Menu bar app** - Lives quietly in your menu bar, no dock icon
- **Plain text storage** - All thoughts saved to `~/Documents/endless.txt` (customizable)
- **Quick entry** - Timestamped entries with a single keystroke (⌘+Enter)
- **Markdown support** - **bold**, *italic*, ~~strikethrough~~, __underline__, and clickable URLs
- **Hashtag support** - `#tags` are highlighted, with autocomplete for previously used tags
- **Search** - Find text with ⌘F, navigate matches with ⌘G / ⌘⇧G
- **Tag jump** - Jump between occurrences of the same hashtag with ⌘J
- **Entry navigation** - Jump between notes with ⌘↑ / ⌘↓
- **5 themes** - Light, Dark, Solarized Dark, Monokai, Nord
- **Customizable shortcuts** - Change all keyboard shortcuts to your preference
- **Launch at login** - Start automatically with your Mac
- **Persistent window** - Remembers position and size

## Download

**[Download endless.txt.dmg](https://github.com/starigade/endless.txt/releases/latest)** (macOS 13.0+)

1. Download `endless.txt.dmg` from the latest release
2. Open the DMG and drag `endless.txt.app` to your Applications folder
3. Launch from Applications or Spotlight

### First Launch (macOS Security)

Since the app is not notarized with Apple, macOS will show a security warning on first launch.

**Option 1:** Right-click the app → **Open** → **Open**

**Option 2:** Run in Terminal:
```bash
xattr -cr /Applications/endless.txt.app
```

This only needs to be done once. The app is open-source and safe to use.

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/starigade/endless.txt.git
   cd endless.txt/endless.txt
   ```

2. Install XcodeGen (if not already installed):
   ```bash
   brew install xcodegen
   ```

3. Generate and open the project:
   ```bash
   xcodegen generate
   open NvrEndingTxt.xcodeproj
   ```

4. Build and run (⌘R)

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘+Shift+Space | Open/close overlay (customizable) |
| ⌘+Enter | Submit quick entry |
| Esc | Dismiss overlay |
| ⌘+, | Open settings |
| Tab / Shift+Tab | Cycle focus between editor and quick entry |

#### Search
| Shortcut | Action |
|----------|--------|
| ⌘+F | Open search |
| ⌘+G | Find next match |
| ⌘+Shift+G | Find previous match |

#### Navigation
| Shortcut | Action |
|----------|--------|
| ⌘+↑ | Jump to previous note (end of note) |
| ⌘+↓ | Jump to next note (end of note) |
| ⌘+Ctrl+↑ | Move to previous line end |
| ⌘+Ctrl+↓ | Move to next line end |
| ⌘+J | Jump to next occurrence of hashtag at cursor |

#### Formatting
| Shortcut | Action |
|----------|--------|
| ⌘+Shift+X | Toggle strikethrough on current line |
| ⌘+Shift+C | Toggle checkbox on current line |
| ⌥+⌘+T | Toggle timestamp visibility |

### Quick Entry

The bottom section is for rapid thought capture. Type your thought and press ⌘+Enter to append it with a timestamp:

```
[2024-02-03 14:30] Your thought here #idea
```

Or with timestamp on a separate line (configurable in settings):

```
[2024-02-03 14:30]
Your thought here #idea
```

### Full Editor

The top section shows your entire text file. Edit freely - changes auto-save.

### Markdown

The editor renders markdown formatting in real-time:

- `**bold**` → **bold**
- `*italic*` → *italic*
- `~~strikethrough~~` → ~~strikethrough~~
- `__underline__` → underlined text
- URLs are automatically detected and made clickable

### Checkboxes

Toggle checkboxes with ⌘+Shift+C:

```
[ ] unchecked task
[x] completed task
```

### Hashtags

Use `#hashtags` to organize your notes:

- Hashtags are highlighted with the theme's accent color
- Type `#` to see autocomplete suggestions of previously used tags
- Click on a hashtag to highlight all occurrences
- Press ⌘+J to jump between occurrences of the same tag

## Settings

Access settings via the menu bar icon or ⌘+,

- **General**
  - Launch at login
  - File location (customizable path)
  - Timezone selection
  - Timestamp display and position options
  - Auto-insert day separators
  - Compact view (remove extra line breaks)
- **Appearance**
  - Theme (5 options)
  - Font family (SF Mono, Menlo, Monaco, Courier New)
  - Font size
  - Markdown toggle
- **Shortcuts**
  - Customize all keyboard shortcuts
- **About**
  - Version and credits

## File Format

All entries are stored as plain text in `~/Documents/endless.txt`:

```
[2024-02-03 09:15] Morning standup notes #work
- reviewed PR #234
- need to fix auth bug

---

[2024-02-04 10:42] idea: cache API responses #idea

[2024-02-04 14:30] meeting with design team
[ ] follow up on designs
[x] send meeting notes
```

Day separators (`---`) are automatically inserted between entries from different days.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building from source)

## Credits

Built by [@starigade](https://github.com/oahnuj)

Inspired by [Jeff Huang's productivity text file](https://jeffhuang.com/productivity_text_file/)
