# FingerText2

FingerText2 is a tab-triggered snippet plugin for [Notepad++](https://notepad-plus-plus.org/). Type a short trigger word, press Tab, and the trigger is replaced by the full snippet body. Snippets support hotspot placeholders for quick cursor navigation, dynamic content via scripts or chain calls, and scope rules that restrict snippets to specific file types or languages.

## Installation

**Via Plugins Admin** (once the plugin is listed): open Notepad++, go to Plugins > Plugins Admin, search for FingerText2, and click Install.

**Manual install**: download the ZIP matching your Notepad++ architecture (`_32bit.zip` or `_64bit.zip`) from the [Releases](https://github.com/ultimatejimmy/FingerText2/releases) page. Extract `FingerText2.dll` into `Notepad++\plugins\FingerText2\FingerText2.dll`.

If you have an existing FingerText (original) install, FingerText2 automatically migrates your snippets database on first launch.

## Documentation

Full usage docs, snippet syntax, scope rules, hotspot reference, and dynamic hotspot types live in the [wiki](https://github.com/ultimatejimmy/FingerText2/wiki).

## Building from source

Run `build.bat` (requires VS 2022 Build Tools with the C++ workload installed), or push to GitHub to let the `build` workflow do it for both Win32 and x64.

## License

MIT. See [LICENSE](LICENSE).
