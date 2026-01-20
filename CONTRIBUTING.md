# Contributing to SweepYourMac

Thanks for your interest in contributing! Here's how you can help.

## Ways to Contribute

- **Report bugs** - Found something broken? Open an issue.
- **Suggest features** - Have an idea? We'd love to hear it.
- **Submit PRs** - Fix bugs or add features yourself.
- **Improve docs** - Help make the README or code comments clearer.

## Development Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/pyramidion-solutions/sweep-your-mac.git
   cd sweep-your-mac
   ```

2. Open in Xcode:
   ```bash
   open SweepYourMac.xcodeproj
   ```

3. Build and run (Cmd+R)

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly on your Mac
5. Commit with a clear message (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Code Style

- Follow existing Swift conventions in the codebase
- Use meaningful variable and function names
- Add comments for complex logic
- Keep scanners as `actor` types for thread safety

## Adding a New Scanner

1. Create scanner in `Services/` (use existing scanners as reference)
2. Add enum case in `Models/ScanCategory.swift`
3. Create view in `Views/`
4. Add routing in `ContentView.swift`

## Safety Guidelines

This app deletes files, so safety is critical:

- Never delete folders themselves, only contents
- Never touch `/System/*`, `/usr/*`, `/bin/*`
- Always check if files are in use with `lsof`
- Default to moving to Trash, not permanent deletion
- Exclude today's files from deletion

## Questions?

Open an issue or start a discussion. We're happy to help!
