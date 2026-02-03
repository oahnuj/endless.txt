# endless.txt

A minimalist, distraction-free, instant thought capture app that lives in your menu bar. One global hotkey, one text file, infinite space for ideas.

Inspired by [Jeff Huang's productivity text file](https://jeffhuang.com/productivity_text_file/).

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Instant capture** - Global hotkey (⌘+Shift+Space) opens overlay in <200ms
- **Menu bar app** - Lives quietly in your menu bar, no dock icon
- **Plain text storage** - All thoughts saved to `~/Documents/nvr-ending.txt`
- **Quick entry** - Timestamped entries with a single keystroke (⌘+Enter)
- **5 themes** - Light, Dark, Solarized Dark, Monokai, Nord
- **Customizable shortcuts** - Change the global hotkey to your preference
- **Launch at login** - Start automatically with your Mac
- **Persistent window** - Remembers position and size

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/oahnuj/endless.txt.git
   cd endless.txt/NvrEndingTxt
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

| Shortcut | Action |
|----------|--------|
| ⌘+Shift+Space | Open/close overlay (customizable) |
| ⌘+Enter | Submit quick entry |
| Esc | Dismiss overlay |
| ⌘+, | Open settings |

### Quick Entry

The bottom section is for rapid thought capture. Type your thought and press ⌘+Enter to append it with a timestamp:

```
[2024-02-03 14:30] Your thought here #idea
```

### Full Editor

The top section shows your entire text file. Edit freely - changes auto-save.

## Settings

Access settings via the menu bar icon or ⌘+,

- **General** - Launch at login, file location, timezone
- **Appearance** - Theme, font family, font size
- **Shortcuts** - Customize the global hotkey
- **About** - Version and credits

## File Format

All entries are stored as plain text in `~/Documents/nvr-ending.txt`:

```
[2024-02-03 09:15] Morning standup notes #work
- reviewed PR #234
- need to fix auth bug

[2024-02-03 10:42] idea: cache API responses #idea

[2024-02-03 14:30] meeting with design team
```

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building from source)

## Credits

Inspired by [Jeff Huang's productivity text file](https://jeffhuang.com/productivity_text_file/)

## License

MIT License - see [LICENSE](LICENSE) for details
