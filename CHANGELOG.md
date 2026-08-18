# Changelog

## 0.2.0 - 2026-08-18

### Added

- Quick-create commands for Temporary Address, DuckDuckGo, and SimpleLogin.
- Clipboard confirmation and native toast feedback for quick-create actions.
- A shared scrollable history surface for temporary addresses and aliases.

### Changed

- Provider controls, search, pagination, and disconnect actions stay visible
  while history cards scroll.
- Disconnected provider setup and plugin settings use compact panel heights.
- DuckDuckGo and SimpleLogin shortcuts are available only when their
  credentials are configured.

### Fixed

- Quick-create success waits for the address to reach the clipboard.
- Provider operations no longer shift the panel while showing progress.

## 0.1.0 - 2026-08-18

- Initial release with Maildrop and Harakiri temporary addresses,
  DuckDuckGo Email Protection aliases, and SimpleLogin alias management.
