"""
Tier 2 functional tests — run after build, gates the draft release.

Requires:
  NPP_EXE  — path to notepad++.exe
  FT2_DLL  — path to FingerText2.dll to install
  FT2_DB   — path to tests/fixtures/FingerText2_seed.db3
  FT2_FTD  — path to tests/fixtures/test_pack.ftd

Coverage (menu-driven — NPP's docked dialog is invisible to the UIA tree;
dock-button paths are reachable via menu commands for the same code paths):
  1. Create Snippet from Selection (text selected) — SnippetEditor.ftb opens
  2. Create Snippet from Selection (empty buffer) — no crash
  3. Tab expansion: type trigger + Tab, verify expanded body
  4. Import from .ftd: file dialog, verify no crash
  5. Data migration: fresh FT2 config, seed old FingerText db, verify migration
"""

import os
import sys
import time
import shutil
import tempfile

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

try:
    import pywinauto
    from pywinauto.application import Application
    from pywinauto.findwindows import ElementNotFoundError
except ImportError as exc:
    print(f"FAIL: pywinauto not installed: {exc}")
    sys.exit(1)

try:
    import pyautogui
    HAS_PYAUTOGUI = True
except ImportError:
    HAS_PYAUTOGUI = False

_DIAG_WIN  = None   # UIA main NPP window (for tree dumps on failure)
_WIN32_WIN = None   # win32 wrapper for menu_select (dock is invisible to UIA)
_tree_dumped = False


# ── Helpers ───────────────────────────────────────────────────────────────────

def screenshot(name: str):
    if HAS_PYAUTOGUI:
        try:
            path = os.path.join(tempfile.gettempdir(), f"ft2_func_{name}.png")
            pyautogui.screenshot(path)
            print(f"  Screenshot: {path}")
        except Exception:
            pass


def dump_tree(tag="tree"):
    """Encoding-safe UIA walker. pywinauto 0.6.8 print_control_identifiers uses
    locale.getpreferredencoding() (cp1252) and crashes on fullwidth chars like
    \\uff0b. Walk children() through the reconfigured utf-8/replace stdout."""
    global _tree_dumped
    _tree_dumped = True

    def walk(elem, depth=0):
        if depth > 20:
            return
        pad = "  " * depth
        try:
            n  = getattr(elem.element_info, "name", "?")
            ct = getattr(elem.element_info, "control_type", "?")
            cl = getattr(elem.element_info, "class_name", "?")
            ai = getattr(elem.element_info, "automation_id", "?")
            print(f"{pad}[{depth}] {ct:20} name={n!r:30} class={cl!r:15} id={ai!r}")
        except Exception as exc:
            print(f"{pad}(error: {exc})")
            return
        try:
            for child in elem.children():
                walk(child, depth + 1)
        except Exception:
            pass

    print(f"---- UIA tree ({tag}) ----")
    if _DIAG_WIN:
        walk(_DIAG_WIN)
    print("---- end ----")


def fail(msg: str, label: str = "failure"):
    screenshot(label)
    if not _tree_dumped:
        dump_tree(label)
    print(f"FAIL: {msg}")
    sys.exit(1)


def env_required(var: str) -> str:
    val = os.environ.get(var)
    if not val:
        print(f"FAIL: environment variable {var} is not set")
        sys.exit(1)
    return val


def no_exception_dialog(app):
    dlgs = app.windows(title_re=".*Plugin.*Exception.*|.*Access.*violation.*|.*PluginsManager.*")
    if dlgs:
        fail("Plugin Exception dialog appeared", "unexpected_exception")


def close_welcome(app, win):
    """Dismiss the 'Welcome to FingerText2' buffer opened on first run."""
    try:
        wd = win.child_window(title_re=".*Welcome to FingerText2.*", timeout=1)
        if wd.exists(timeout=1):
            win.type_keys("^w")
            time.sleep(0.5)
            for dlg in app.windows(title_re=".*Save.*|.*Notepad.*"):
                try:
                    dlg.child_window(title_re=".*Don.*t Save.*|.*No.*",
                                     control_type="Button").click_input()
                except Exception:
                    pass
    except Exception:
        pass


def menu_cmd(path: str):
    """Fire an NPP menu command via the win32 backend.
    The FingerText2 dock panel is absent from the UIA tree, but menu commands
    always work and reach the same underlying C++ functions as the dock buttons.
    Example: menu_cmd("Plugins->FingerText2->Create Snippet from Selection")
    """
    _WIN32_WIN.menu_select(path)
    time.sleep(0.5)


# ── Setup ─────────────────────────────────────────────────────────────────────

npp_exe = env_required("NPP_EXE")
ft2_dll = env_required("FT2_DLL")
ft2_db  = env_required("FT2_DB")
ft2_ftd = env_required("FT2_FTD")

for path, name in [(npp_exe, "NPP_EXE"), (ft2_dll, "FT2_DLL"),
                   (ft2_db, "FT2_DB"), (ft2_ftd, "FT2_FTD")]:
    if not os.path.isfile(path):
        fail(f"{name} does not exist: {path}")

npp_dir = os.path.dirname(npp_exe)
appdata = os.environ.get("APPDATA", "")
# Portable NPP (doLocalConf.xml present) stores plugin config inside its own tree.
# System-installed NPP stores it in APPDATA.
if os.path.isfile(os.path.join(npp_dir, "doLocalConf.xml")):
    _npp_plugin_cfg = os.path.join(npp_dir, "plugins", "config")
else:
    _npp_plugin_cfg = os.path.join(appdata, "Notepad++", "plugins", "config")
ft2_cfg = os.path.join(_npp_plugin_cfg, "FingerText2")


def install_plugin():
    plugin_dir = os.path.join(npp_dir, "plugins", "FingerText2")
    os.makedirs(plugin_dir, exist_ok=True)
    shutil.copy2(ft2_dll, os.path.join(plugin_dir, "FingerText2.dll"))


def seed_database():
    os.makedirs(ft2_cfg, exist_ok=True)
    shutil.copy2(ft2_db, os.path.join(ft2_cfg, "FingerText2.db3"))


def launch_npp():
    global _DIAG_WIN, _WIN32_WIN, _tree_dumped
    _tree_dumped = False
    install_plugin()
    app = Application(backend="uia").start(
        f'"{npp_exe}" -multiInst -nosession', timeout=30
    )
    win = app.window(title_re=".*Notepad\\+\\+.*", control_type="Window")
    win.wait("visible", timeout=20)
    time.sleep(2)
    no_exception_dialog(app)
    close_welcome(app, win)
    _DIAG_WIN = win
    # Connect win32 backend to the same process for menu commands.
    # The docked FingerText2 dialog does not appear in the UIA tree at all
    # (confirmed: wedockspliter container shows empty); win32 menu_select works.
    app32 = Application(backend="win32").connect(process=app.process)
    _WIN32_WIN = app32.window(class_name="Notepad++")
    return app, win


def quit_npp(app, win):
    import subprocess
    pid = app.process
    win.close()
    time.sleep(1)
    for dlg in app.windows(title_re=".*Save.*|.*Notepad.*"):
        try:
            dlg.child_window(title_re=".*Don.*t Save.*|.*No.*",
                             control_type="Button").click_input()
        except Exception:
            pass
    time.sleep(0.5)
    try:
        app.wait_for_process_exit(timeout=8)
    except Exception:
        pass
    # Force-kill if still running (e.g. a save dialog was missed)
    subprocess.run(["taskkill", "/PID", str(pid), "/F"],
                   capture_output=True, timeout=5)
    time.sleep(0.5)


# ── Test 1: Create Snippet from Selection (text selected) ─────────────────────

print("\n[Test 1] Create Snippet from Selection (text selected)")
seed_database()
app, win = launch_npp()

try:
    win.type_keys("^n"); time.sleep(0.5)
    sci = win.child_window(class_name="Scintilla")
    sci.click_input()
    win.type_keys("test snippet content", with_spaces=True); time.sleep(0.3)
    win.type_keys("^a"); time.sleep(0.3)

    menu_cmd("Plugins->FingerText2->Create Snippet from Selection")
    time.sleep(1.5)

    no_exception_dialog(app)

    tab = win.child_window(control_type="TabItem", title_re=".*SnippetEditor.*")
    tab.wait("visible", timeout=5)

except ElementNotFoundError as exc:
    fail(f"Test 1 element not found: {exc}", "test1_not_found")

quit_npp(app, win)
print("  [PASS] Create Snippet from Selection (text selected)")


# ── Test 2: Create Snippet from Selection (empty buffer) ──────────────────────

print("\n[Test 2] Create Snippet from Selection (empty buffer) — no crash")
seed_database()
app, win = launch_npp()

try:
    win.type_keys("^n"); time.sleep(0.5)

    menu_cmd("Plugins->FingerText2->Create Snippet from Selection")
    time.sleep(1.5)

    no_exception_dialog(app)

except ElementNotFoundError as exc:
    fail(f"Test 2 element not found: {exc}", "test2_not_found")

quit_npp(app, win)
print("  [PASS] Create Snippet from Selection (empty buffer)")


# ── Test 3: Tab expansion ─────────────────────────────────────────────────────

print("\n[Test 3] Tab expansion of 'testtrigger'")
seed_database()
app, win = launch_npp()

try:
    win.type_keys("^n"); time.sleep(0.5)
    sci = win.child_window(class_name="Scintilla")
    sci.click_input()
    win.type_keys("testtrigger{TAB}", with_spaces=True)
    time.sleep(1)

    no_exception_dialog(app)

    sci_text = sci.window_text()
    if "Hello from FingerText2" not in sci_text and "testtrigger" in sci_text:
        win.type_keys("^a^c")
        time.sleep(0.3)
        import tkinter as tk
        root = tk.Tk(); root.withdraw()
        clipboard = root.clipboard_get(); root.destroy()
        if "Hello from FingerText2" not in clipboard:
            fail(f"Expansion did not produce expected text. Got: {clipboard[:200]}",
                 "test3_wrong_text")

except ElementNotFoundError as exc:
    fail(f"Test 3 element not found: {exc}", "test3_not_found")

quit_npp(app, win)
print("  [PASS] Tab expansion")


# ── Test 4: Import from .ftd ──────────────────────────────────────────────────

print("\n[Test 4] Import snippets from .ftd file")
seed_database()
app, win = launch_npp()

try:
    menu_cmd("Plugins->FingerText2->Import Snippets from ftd file")
    time.sleep(1)

    # The file-open dialog is a top-level Win32 dialog — visible via UIA
    file_dlg = app.window(title_re=".*Open.*|.*Import.*", control_type="Window")
    file_dlg.wait("visible", timeout=5)
    # Filename field is focused when the dialog opens; type path directly.
    # Backslashes are not special in pywinauto type_keys.
    file_dlg.type_keys(os.path.abspath(ft2_ftd), with_spaces=True)
    time.sleep(0.3)
    file_dlg.type_keys("{ENTER}")
    time.sleep(2)

    no_exception_dialog(app)

    for dlg in app.windows(title_re=".*Import.*|.*Success.*|.*FingerText.*"):
        try:
            ok = dlg.child_window(title_re=".*OK.*|.*Close.*", control_type="Button")
            ok.click_input()
        except Exception:
            pass

except ElementNotFoundError as exc:
    fail(f"Test 4 element not found: {exc}", "test4_not_found")

quit_npp(app, win)
print("  [PASS] Import from .ftd")


# ── Test 5: About dialog (regression) ─────────────────────────────────────────

print("\n[Test 5] About dialog opens without crash")
seed_database()
app, win = launch_npp()

try:
    menu_cmd("Plugins->FingerText2->About")
    time.sleep(0.5)

    # The About dialog is a top-level modal (not docked), so it's visible to UIA
    about_dlg = app.window(title_re=".*About FingerText2.*", control_type="Window")
    about_dlg.wait("visible", timeout=5)

    # If we get here, the dialog opened and NPP didn't crash (a dead process would fail the UIA call)
    no_exception_dialog(app)

    # Close the dialog
    about_dlg.type_keys("{ENTER}")
    time.sleep(0.5)

except ElementNotFoundError as exc:
    fail(f"Test 5 element not found: {exc}", "test5_about_not_found")

quit_npp(app, win)
print("  [PASS] About dialog")


# ── Test 6: Data migration ────────────────────────────────────────────────────

print("\n[Test 6] Migration from config\\FingerText")
old_cfg = os.path.join(_npp_plugin_cfg, "FingerText")
old_db  = os.path.join(old_cfg, "FingerText.db3")
new_db  = os.path.join(ft2_cfg, "FingerText2.db3")

if os.path.exists(ft2_cfg):
    shutil.rmtree(ft2_cfg)
os.makedirs(old_cfg, exist_ok=True)
shutil.copy2(ft2_db, old_db)

install_plugin()
app, win = launch_npp()

try:
    time.sleep(2)
    no_exception_dialog(app)

    if not os.path.isfile(new_db):
        fail(f"Migration did not create {new_db}", "test5_no_migration")

    if os.path.getsize(new_db) < os.path.getsize(ft2_db) * 0.5:
        fail("Migrated db3 is suspiciously small", "test5_small_db")

except ElementNotFoundError as exc:
    fail(f"Test 5 element not found: {exc}", "test5_not_found")

quit_npp(app, win)
print("  [PASS] Data migration")


# ── Done ──────────────────────────────────────────────────────────────────────
print("\nAll functional tests PASSED")
sys.exit(0)
