"""Theme integration source contracts; does not run AHK or assert visual results.

Run: python -X utf8 tools/test_theme_contract.py [--root PATH]
The --root option checks the same contracts against an isolated baseline copy.
"""
from pathlib import Path
import argparse
import re
import unittest

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
args = parser.parse_args()
ROOT = args.root
UI = [f'src/lib/ui/{name}.ahk' for name in
      ('gui', 'custom_key_editor', 'changelog_ui', 'updater_ui', 'status_bar')]
UI.append('src/lib/base/message_box.ahk')


def read(name):
    return (ROOT / name).read_text(encoding='utf-8-sig')


def method(source, name):
    match = re.search(r'^    static ' + re.escape(name) + r'\(', source, re.M)
    if not match:
        raise AssertionError(f'Missing method {name}')
    end = re.search(r'^    static ', source[match.end():], re.M)
    return source[match.start():match.end() + end.start()] if end else source[match.start():]


def balanced(source):
    """Check delimiters outside AHK quoted strings and comments (not an AHK parser)."""
    stack, quote, block = [], None, False
    i = 0
    while i < len(source):
        ch = source[i]
        if block:
            if source[i:i+2] == '*/':
                block = False
                i += 2
            else:
                i += 1
            continue
        if quote:
            if ch == '`':
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if source[i:i+2] == '/*':
            block = True
            i += 2
            continue
        if ch == ';':
            end = source.find('\n', i)
            i = len(source) if end < 0 else end + 1
            continue
        if ch in ('"', "'"):
            quote = ch
        elif ch in '([{':
            stack.append(ch)
        elif ch in ')]}':
            if not stack or stack.pop() != {')': '(', ']': '[', '}': '{'}[ch]:
                return False
        i += 1
    return not stack and quote is None and not block


class ThemeContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.theme = read('src/lib/base/theme.ahk')
        cls.gui = read('src/lib/ui/gui.ahk')
        cls.service = read('src/lib/core/settings/settings_service.ahk')

    def test_mode_default_and_config_boundaries(self):
        config = read('src/lib/base/config.ahk')
        self.assertIn('"ThemeMode", "auto"', config)
        self.assertIn('"ThemeMode", "界面主题"', read('src/lib/base/constants.ahk'))
        for name in ('GetImportant', 'ReadImportantFromIni', 'SetImportant', 'LoadFromIni'):
            self.assertIn('Theme.Normalize', method(config, name))

    def test_success_and_cancel_end_preview(self):
        save = method(self.service, '_SaveOrApply')
        self.assertLess(save.index('!this._ValidateAndPersist()'), save.index('Theme.Confirm'))
        self.assertLess(save.index('Theme.Confirm'), save.index('this._RefreshRuntime()'))
        cancel = method(self.service, 'Cancel')
        self.assertLess(cancel.index('Config.LoadFromIni()'), cancel.index('Theme.Confirm'))
        self.assertIn('Theme.Confirm', method(self.service, 'Initialize'))

    def test_startup_backfills_only_missing_theme_mode(self):
        startup = method(self.service, 'Initialize')
        missing = 'if (IniRead(Config.IniFile, "Main", "ThemeMode", "__AFA_MISSING_KEY__") = "__AFA_MISSING_KEY__") {'
        write = 'Config._PersistSingleValue("ThemeMode", "auto")'
        self.assertIn(missing, startup)
        self.assertLess(startup.index('Config.LoadFromIni()'), startup.index(missing))
        self.assertLess(startup.index(missing), startup.index(write))
        self.assertLess(startup.index(write), startup.index('Theme.Confirm'))
        self.assertIn('if !themeBackfill.success', startup)
        self.assertIn('Logger.Warn', startup)
        for name in ('Cancel', 'Reset', '_RefreshRuntime'):
            self.assertNotIn(write, method(self.service, name))

    def test_atomic_theme_write_uses_object_property_check(self):
        writer = method(read('src/lib/base/config.ahk'), '_WriteIniEntriesAtomic')
        self.assertIn('entry.HasOwnProp("Value")', writer)
        self.assertNotIn('entry.Has("Value")', writer)

    def test_hotkey_reset_preserves_preview(self):
        for name in ('Reset', '_RefreshRuntime'):
            self.assertNotIn('Theme.Confirm', method(self.service, name))
        self.assertNotIn('Theme.', method(self.gui, 'SwitchTab'))

    def test_theme_is_persisted_after_custom_keys(self):
        save = method(self.service, '_ValidateAndPersist')
        self.assertIn('finally Config.SetImportant("ThemeMode", themeMode)', save)
        self.assertLess(save.index('CustomHotkeyStore.Save('),
                        save.index('Config._PersistSingleValue("ThemeMode", themeMode)'))

    def test_preview_is_part_of_existing_dirty_tracking(self):
        track = method(self.gui, 'TrackChange')
        self.assertIn('Config.SetImportant("ThemeMode", mode)', track)
        self.assertIn('Theme.Preview(mode)', track)
        self.assertRegex(self.gui, r'GuiImportantKeys := \[[\s\S]*?"ThemeMode"\]')
        self.assertIn('if !this.IsModified', method(self.gui, 'Show'))

    def test_symbolic_colors_have_matching_palettes(self):
        palettes = []
        for name in ('Light', 'Dark'):
            match = re.search(r'static ' + name + r' := Map\((.*?)\)\n', self.theme, re.S)
            self.assertIsNotNone(match)
            palettes.append(dict(re.findall(r'"(\w+)", "([0-9A-F]{6})"', match[1])))
        self.assertEqual(palettes[0].keys(), palettes[1].keys())
        for name in UI:
            source = read(name)
            for role in re.findall(r'Background([A-Z]\w+)', source):
                self.assertTrue(role == 'Trans' or role in palettes[0], (name, role))
            for role in re.findall(r'\bc([A-Z]\w+)\b', source):
                self.assertIn(role, palettes[0], (name, role))
            self.assertNotRegex(source, r'\bc[0-9A-Fa-f]{6}\b|Background[0-9A-Fa-f]{6}\b')

    def test_all_app_controls_use_theme_adapter(self):
        for name in UI:
            source = read(name)
            self.assertNotRegex(source, r'(?<!Theme)\.Add\("(?:Text|Button|Checkbox|Edit|DropDownList|GroupBox|Picture|UpDown|Progress)"')
            self.assertNotIn('BackColor := "FFFFFF"', source)
            self.assertNotRegex(source, r'(?<!Theme)\.SetFont\(')
            self.assertNotRegex(source, r'(?<!Theme)\.Destroy\(')

    def test_adapter_calls_resolve(self):
        methods = set(re.findall(r'^    static (\w+)\(', self.theme, re.M))
        for name in UI + ['src/lib/base/config.ahk', 'src/lib/core/settings/settings_service.ahk']:
            for called in re.findall(r'\bTheme\.(\w+)\(', read(name)):
                self.assertIn(called, methods, (name, called))

    def test_system_detection_is_readonly_and_debounced(self):
        self.assertIn('"AppsUseLightTheme", 1', self.theme)
        self.assertNotIn('RegWrite', self.theme)
        self.assertIn('SetTimer(this._RefreshCallback, -50)', self.theme)
        self.assertIn('SystemParametersInfoW', self.theme)
        self.assertIn('Theme.Refresh()', method(self.gui, 'Show'))

    def test_repaint_preserves_native_controls(self):
        self.assertIn('SetWindowSubclass', self.theme)
        self.assertIn('DefSubclassProc', method(self.theme, '_Subclass'))
        self.assertNotIn('.Destroy', method(self.theme, '_Refresh'))
        self.assertNotIn('GuiManager', self.theme)
        self.assertNotIn('HotkeyService', self.theme)

    def test_callback_and_gdi_lifetime(self):
        for name in ('BeginPaint', 'EndPaint', 'SaveDC', 'RestoreDC', 'DeleteObject', 'RemoveWindowSubclass', 'CallbackFree'):
            self.assertIn(name, self.theme)
        self.assertIn('this.Detach(gui.Hwnd)', method(self.theme, 'Destroy'))
        self.assertIn('this._DeleteBrushes()', method(self.theme, 'Stop'))

    def test_edit_border_keeps_native_client_painting(self):
        add = method(self.theme, 'Add')
        self.assertRegex(add, r'if \(kind = "Edit" \|\| kind = "Button"')
        subclass = method(self.theme, '_Subclass')
        self.assertIn('if (data.Ctrl.Type = "Edit")', subclass)
        self.assertLess(subclass.index('this._EditMessage('), subclass.index('this._Paint('))
        edit = method(self.theme, '_EditMessage')
        self.assertIn('DefSubclassProc', edit)
        self.assertIn('this.IsDark && !this.HighContrast', edit)
        self.assertIn('msg = 0x0085', edit)
        self.assertIn('0x0007, 0x0008, 0x000A', edit)
        self.assertIn('return result', edit)

    def test_edit_border_releases_dc_without_changing_geometry(self):
        paint = method(self.theme, '_PaintEditBorder')
        for token in ('GetWindowDC', 'ReleaseDC', 'finally', 'GetWindowRect', '"Border"', '"Accent"', '"Field"'):
            self.assertIn(token, paint)
        self.assertNotIn('SetWindowLong', paint)
        self.assertNotIn('.Move(', paint)
        self.assertIn('0x0485', method(self.theme, '_Refresh'))

    def test_includes_have_no_theme_startup_side_effects(self):
        self.assertIn('#Include ./lib/base/theme.ahk', read('src/main.ahk'))
        self.assertIn('#Include ../../src/lib/base/theme.ahk', read('test/scripts/smoke_test.ahk'))
        self.assertNotRegex(self.theme, re.compile(r'^\s*static \w+\s*:=.*(?:DllCall|CallbackCreate|RegRead|OnMessage)\(', re.M))

    def test_changed_ahk_delimiters(self):
        for name in UI + ['src/lib/base/theme.ahk', 'src/lib/base/config.ahk',
                          'src/lib/core/settings/settings_service.ahk']:
            self.assertTrue(balanced(read(name)), name)


if __name__ == '__main__':
    unittest.main(argv=['test_theme_contract'], verbosity=2)
