"""Custom appearance source contracts. Native behavior is tested separately in AHK."""
import re
import unittest
from test_theme_contract import read, method, balanced


class CustomThemeContracts(unittest.TestCase):
    def test_theme_edit_button_layout_and_visibility(self):
        gui = read('src/lib/ui/gui.ahk')
        self.assertIn('ddTheme.GetPos(&themeX, &themeY, &themeW, &themeH)', gui)
        self.assertIn('(themeX + themeW + 12)', gui)
        self.assertIn('" h28 Hidden"', gui)
        visibility = method(gui, '_UpdateThemeEditButtonVisibility')
        for condition in ('this.CurrentTab = "other"', 'this.CurrentOtherCategory = "Display"',
                          'Config.GetImportant("ThemeMode") = "custom"'):
            self.assertIn(condition, visibility)
        self.assertIn('this.ThemeEditButton.Visible :=', visibility)
        for caller in ('TrackChange', '_OnSettingsChanged', '_UpdateImportantControlsFromConfig', '_SwitchOtherCategory'):
            self.assertIn('this._UpdateThemeEditButtonVisibility()', method(gui, caller))
        category = method(gui, '_SwitchOtherCategory')
        self.assertLess(category.index('ctrl.Visible := true'), category.index('this._UpdateThemeEditButtonVisibility()'))

    def test_save_locals_do_not_shadow_appearance_class(self):
        service = read('src/lib/core/settings/settings_service.ahk')
        self.assertNotRegex(service, r'(?im)^\s*appearance\s*:=')
        self.assertIn('appearanceSnapshot := Appearance.Snapshot()', service)

    def test_color_picker_explicitly_updates_draft(self):
        picker = method(read('src/lib/ui/theme_editor.ahk'), 'PickColor')
        self.assertIn('this.Update()', picker)
        self.assertLess(picker.index('this.Inputs[key].Value :='), picker.index('this.Update()'))

    def test_group_fields_registered_in_config(self):
        model = read('src/lib/base/appearance.ahk')
        keys = re.findall(r'"(Theme\w+)", "[^"]*"', model.split('static ColorKeys')[0])
        self.assertEqual(len(keys), 8)
        for key in keys:
            self.assertIn(f'"{key}",', read('src/lib/base/config.ahk'))
            self.assertIn(f'"{key}",', read('src/lib/base/constants.ahk'))

    def test_preview_snapshot_is_distinct_from_config(self):
        theme = read('src/lib/base/theme.ahk')
        self.assertIn('Appearance.Normalize(values)', method(theme, 'Preview'))
        self.assertNotIn('SetWorking', method(theme, 'Preview'))
        gui = read('src/lib/ui/gui.ahk')
        self.assertIn('Appearance.Snapshot()', method(gui, 'CaptureInitialSnapshot'))
        self.assertIn('Appearance.Equal', method(gui, '_AllControlsMatchSnapshot'))

    def test_editor_fixed_and_cancellable(self):
        editor = read('src/lib/ui/theme_editor.ahk')
        self.assertIn('Theme.Attach(windowGui, true)', editor)
        self.assertIn('Theme.Preview(this.Original["ThemeMode"], this.Original)', method(editor, 'Cancel'))
        self.assertIn('Appearance.SetWorking(this.Draft)', method(editor, 'Accept'))
        self.assertNotIn('IniWrite', editor)
        self.assertNotIn('FileCopy', editor)
        self.assertIn('this.Owner.Opt("-Disabled")', method(editor, 'Close'))
        self.assertIn('SetTimer(this.PreviewCallback, 0)', method(editor, 'Close'))

    def test_atomic_group_commit_after_other_saves(self):
        service = read('src/lib/core/settings/settings_service.ahk')
        save = method(service, '_ValidateAndPersist')
        self.assertLess(save.index('BackgroundImage.Stage'), save.index('Config.SaveAllToIni'))
        self.assertLess(save.index('CustomHotkeyStore.Save'), save.index('this._PersistAppearance'))
        self.assertIn('BackgroundImage.Discard(prepared.Created)', save)
        writer = method(service, '_PersistAppearance')
        self.assertEqual(writer.count('Config._WriteIniEntriesAtomic'), 1)
        self.assertIn('finally Critical(wasCritical)', writer)

    def test_no_image_io_in_paint_callbacks(self):
        source = read('src/lib/base/theme.ahk')
        for name in ('_EraseBackground', '_ControlBrush', '_Fill', '_Paint'):
            body = method(source, name)
            for forbidden in ('BackgroundImage.Load(', 'BackgroundImage.Prepare(', 'FileRead(', 'GdipLoad'):
                self.assertNotIn(forbidden, body)
        refresh = method(source, 'Refresh')
        self.assertLess(refresh.index('BackgroundImage.Prepare'), refresh.index('Critical("On")'))

    def test_image_bounds_and_owned_cleanup(self):
        source = read('src/lib/base/background_image.ahk')
        self.assertIn('20 * 1024 * 1024', source)
        self.assertIn('16000000', source)
        discard = method(source, 'Discard')
        self.assertIn('directory = this.Directory()', discard)
        self.assertIn('this.IsManaged(name)', discard)
        self.assertIn('GdiplusShutdown', method(source, 'Stop'))
        self.assertIn('FreeLibrary', method(source, 'Stop'))

    def test_cache_covers_complete_appearance(self):
        source = read('src/lib/base/background_image.ahk')
        self.assertIn('w ":" h ":" Appearance.Signature(values)', method(source, 'Prepare'))
        theme = read('src/lib/base/theme.ahk')
        self.assertIn('Appearance.Signature(this.CurrentAppearance())', method(theme, '_Refresh'))
        self.assertIn('this.CustomActive && !this.HighContrast', method(theme, 'Refresh'))
        self.assertNotIn('WinSetTransColor', read('src/lib/ui/gui.ahk'))

    def test_new_modules_have_balanced_delimiters(self):
        for name in ('src/lib/base/appearance.ahk', 'src/lib/base/background_image.ahk', 'src/lib/ui/theme_editor.ahk'):
            self.assertTrue(balanced(read(name)), name)


if __name__ == '__main__':
    unittest.main(argv=['test_custom_theme_contract'], verbosity=2)
