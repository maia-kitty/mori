"""Exercise power-command editing and actual settings-file persistence headlessly."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from qml_helpers import headless_settings


SOURCE = Path(__file__).resolve().parents[1] / "quickshell/.config/quickshell/mori"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for QML checks")
class PowerSettingsTests(unittest.TestCase):
    def run_settings(self, checks, initial=None):
        with tempfile.TemporaryDirectory(prefix="mori-settings-") as tmp:
            base = Path(tmp)
            (base / "mori").mkdir()
            for name in ("SettingsStore.qml", "PowerCommands.js", "ScrollableColumn.qml", "SettingsLabel.qml", "BarLabel.qml"):
                shutil.copyfile(SOURCE / name, base / "mori" / name)
            shutil.copytree(SOURCE / "theme", base / "mori/theme")

            source = (SOURCE / "MoriSettings.qml").read_text()
            # Keep every actual page and its Loader, replacing only the
            # platform window; external commands use an isolated empty PATH.
            (base / "mori/MoriSettings.qml").write_text(headless_settings(source))

            config = base / "config/quickshell/mori-settings.json"
            config.parent.mkdir(parents=True)
            if initial is not None:
                config.write_text(json.dumps(initial))
            (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "mori" as Mori
import "mori/PowerCommands.js" as PowerCommands
ShellRoot {
    Mori.SettingsStore { id: store }
    Mori.MoriSettings {
        id: editor
        settings: store
        panelWindow: coordinator
        popupCoordinator: coordinator
        width: 560
        height: 550
    }
    QtObject {
        id: coordinator
        function showPopup(item) {}
        function hidePopup(item) {}
    }
    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
''' + checks + "\n}\n")
            runtime = base / "run"
            runtime.mkdir(mode=0o700)
            (base / "bin").mkdir()
            env = dict(
                os.environ, QT_QPA_PLATFORM="offscreen",
                XDG_CONFIG_HOME=str(base / "config"),
                XDG_CACHE_HOME=str(base / "cache"),
                XDG_RUNTIME_DIR=str(runtime), PATH=str(base / "bin"),
            )
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                [shutil.which("qs"), "--path", str(base / "shell.qml"), "--no-color"],
                env=env, capture_output=True, text=True, timeout=10,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("MORI_SETTINGS_CHECK_PASS", output)
            for error in ("ReferenceError", "TypeError", "Binding loop", "Unable to assign"):
                self.assertNotIn(error, output)
            return json.loads(config.read_text()) if config.exists() else None

    def test_editor_apply_automatic_discard_and_preservation(self):
        checks = '''
    Timer {
        interval: 300; running: true
        onTriggered: {
            editor.testOpen("power")
            check(editor.categoryPages.indexOf("power") >= 0, "Missing settings category")
            check(editor.powerDrafts.suspend === "doas -n zzz", "Stored command not loaded")
            check(editor.testField(0).text === "doas -n zzz", "Field did not load")
            const field = editor.testField(1)
            field.text = "'unfinished"
            field.textEdited()
            check(!editor.powerDraftsValid, "Incomplete quotes accepted")
            editor.applyPowerCommands()
            check(store.powerCommands.reboot[0] === "old-wrapper", "Invalid edits saved")
            field.text = "'/path with spaces/wrapper' --no-ask-password"
            field.textEdited()
            check(editor.powerDraftsValid, "Valid command rejected")
            editor.applyPowerCommands()
            check(store.powerCommands.reboot[0] === "/path with spaces/wrapper", "Path split")
            check(store.powerCommands.reboot[1] === "--no-ask-password", "Flag lost")
            editor.setPowerDraft("poweroff", "")
            editor.applyPowerCommands()
            check(!("poweroff" in store.powerCommands), "Automatic did not remove override")
            store.setClockOption("showSeconds", true)
            store.setModuleEnabled("calendar", false)
            editor.setPowerDraft("suspend", "discard-this-wrapper")
            editor.finishClose()
            editor.testOpen("power")
            check(editor.powerDrafts.suspend === "doas -n zzz", "Unapplied edits survived close")
            check(!store.setPowerCommands({suspend: []}), "Invalid command accepted by store")
            console.log("MORI_SETTINGS_CHECK_PASS")
            Qt.quit()
        }
    }
'''
        saved = self.run_settings(checks, {
            "power": {"suspend": ["doas", "-n", "zzz"], "reboot": ["old-wrapper"], "poweroff": ["old-poweroff"]},
        })
        self.assertEqual(saved["power"], {
            "suspend": ["doas", "-n", "zzz"],
            "reboot": ["/path with spaces/wrapper", "--no-ask-password"],
        })
        self.assertTrue(saved["clock"]["showSeconds"])
        self.assertFalse(saved["modules"]["calendar"])

    def test_external_power_edits_survive_other_setting_changes(self):
        checks = '''
    FileView {
        id: external
        path: store.configRoot + "/quickshell/mori-settings.json"
        blockWrites: true
        atomicWrites: true
        printErrors: false
    }
    Timer {
        property int phase: 0
        interval: 300; running: true
        onTriggered: {
            if (phase === 0) {
                external.setText(JSON.stringify({power: {suspend: ["external-wrapper", "-n"]}}))
                phase++
                interval = 500
                restart()
            } else {
                check(store.powerCommands.suspend[0] === "external-wrapper", "External edit not reloaded")
                store.setClockOption("showSeconds", true)
                console.log("MORI_SETTINGS_CHECK_PASS")
                Qt.quit()
            }
        }
    }
'''
        saved = self.run_settings(checks, {"power": {"suspend": ["old-wrapper"]}})
        self.assertEqual(saved["power"]["suspend"], ["external-wrapper", "-n"])
        self.assertTrue(saved["clock"]["showSeconds"])

    def test_automatic_can_repair_an_invalid_saved_power_section(self):
        checks = '''
    Timer {
        interval: 100; running: true
        onTriggered: {
            editor.testOpen("power")
            check(editor.powerDirty, "Invalid section was not marked for repair")
            editor.setPowerDraft("suspend", "")
            editor.applyPowerCommands()
            check(JSON.stringify(store.powerCommands) === "{}", "Automatic did not repair section")
            console.log("MORI_SETTINGS_CHECK_PASS")
            Qt.quit()
        }
    }
'''
        self.assertEqual(self.run_settings(checks, {"power": None})["power"], {})

    def test_command_parser_preserves_literal_quoting(self):
        checks = r'''
    Timer {
        interval: 100; running: true
        onTriggered: {
            const commands = [
                ["sudo", "-n", "systemctl", "poweroff"],
                ["/path with spaces/wrapper", "it's quoted", "$(reboot)", "`poweroff`", "line\nbreak", "a\\b"],
                ["loginctl", "--no-ask-password", "suspend"]
            ]
            for (const command of commands)
                check(JSON.stringify(PowerCommands.parse(PowerCommands.format(command)))
                    === JSON.stringify(command), "Command roundtrip lost arguments")
            check(PowerCommands.parse("  ").length === 0, "Blank is not automatic")
            check(JSON.stringify(PowerCommands.parse('wrapper "two words" escaped\\ space'))
                === JSON.stringify(["wrapper", "two words", "escaped space"]), "Quote parsing failed")
            for (const text of ["wrapper '", "wrapper \\", 'wrapper ""', "wrapper\u0000"]) {
                let rejected = false
                try { PowerCommands.parse(text) } catch (error) { rejected = true }
                check(rejected, "Malformed command accepted")
            }
            console.log("MORI_SETTINGS_CHECK_PASS")
            Qt.quit()
        }
    }
'''
        self.run_settings(checks)


if __name__ == "__main__":
    unittest.main()
