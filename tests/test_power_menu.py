"""Headless checks of the real menu logic, delegates, and hold timers.

Platform windows are omitted because offscreen Quickshell has no panel backend.
All dispatched power commands use a temporary mock helper.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "quickshell/.config/quickshell/mori"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is required for QML checks")
class PowerMenuTests(unittest.TestCase):
    def check_menu(self, checks, helper=None):
        with tempfile.TemporaryDirectory(prefix="mori-qml-") as tmp:
            base = Path(tmp)
            (base / "bin").mkdir()
            if helper is not None:
                executable = base / "bin/mori-power"
                executable.write_text("#!/bin/sh\n" + helper)
                executable.chmod(0o755)

            source = (SOURCE / "PowerMenu.qml").read_text()
            logic = source.split("    BarLabel {", 1)[0]
            column = "            Column {" + source.split("            Column {", 1)[1].split(
                "\n        }\n    }\n\n    PanelWindow {", 1
            )[0]
            (base / "mori").mkdir()
            (base / "mori/PowerMenu.qml").write_text(logic + '''
    QtObject { id: powerIcon; property int implicitWidth: 16; property int implicitHeight: 16 }
    QtObject { id: menu; property bool visible: false }
''' + column + "\n}\n")
            shutil.copytree(SOURCE / "theme", base / "mori/theme")
            (base / "shell.qml").write_text('''import QtQuick
import Quickshell
import "mori" as Mori
ShellRoot {
    Mori.PowerMenu {
        id: power
        panelWindow: coordinator
        popupCoordinator: coordinator
    }
    QtObject {
        id: coordinator
        function showPopup(item) {}
        function hidePopup(item) {}
    }
    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
    function key(code) { return {key: code, isAutoRepeat: false, accepted: false} }
''' + checks + "\n}\n")
            runtime = base / "run"
            runtime.mkdir(mode=0o700)
            env = dict(
                os.environ,
                QT_QPA_PLATFORM="offscreen",
                XDG_CACHE_HOME=str(base / "cache"),
                XDG_RUNTIME_DIR=str(runtime),
                # No installed power helper can accidentally be invoked.
                PATH=str(base / "bin"),
                MORI_TEST_LOG=str(base / "dispatches"),
            )
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(
                [shutil.which("qs"), "--path", str(base / "shell.qml"), "--no-color"],
                env=env, capture_output=True, text=True, timeout=10,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("MORI_QML_CHECK_PASS", output)
            log = base / "dispatches"
            return log.read_text().splitlines() if log.exists() else []

    def test_availability_shortcuts_hold_cancellation_and_error(self):
        helper = '''case "$1" in
--resolve) printf '%s\\n' '{"suspend":{"command":["mock"],"error":""},"reboot":{"command":["mock"],"error":""},"poweroff":{"command":[],"error":"Unavailable test action"}}' ;;
*) printf '%s\\n' "$1" >> "$MORI_TEST_LOG"; echo 'Mock permission failure' >&2; exit 7 ;;
esac
'''
        checks = '''
    Component.onCompleted: {
        check(!power.actionAvailable({action: "suspend"}), "Initially enabled")
        power.toggle()
    }
    Timer {
        property int phase: 0
        interval: 300; running: true
        onTriggered: {
            if (phase === 0) {
                check(!power.resolving, "Still resolving")
                check(power.actionAvailable({action: "suspend"}), "Suspend disabled")
                check(!power.actionAvailable({action: "poweroff"}), "Poweroff enabled")
                power.handleKeyPressed(key(Qt.Key_P))
                check(power.selectedActionIndex === 4, "Disabled shortcut shifted")
                interval = 900
            } else if (phase === 1) {
                check(!power.actionPending, "Disabled action dispatched")
                power.handleKeyReleased(key(Qt.Key_P))
                power.handleKeyPressed(key(Qt.Key_R))
                check(power.selectedActionIndex === 3, "Restart shortcut shifted")
                interval = 200
            } else if (phase === 2) {
                power.handleKeyReleased(key(Qt.Key_R))
                interval = 900
            } else if (phase === 3) {
                check(power.errorMessage === "Unavailable test action", "Short hold dispatched")
                power.handleKeyPressed(key(Qt.Key_Return))
                interval = 1100
            } else {
                check(!power.actionPending, "Action still pending")
                check(power.errorMessage === "Mock permission failure", "Failure detail lost")
                check(!power.heldEnter && power.heldActionKey === 0, "Hold not reset")
                console.log("MORI_QML_CHECK_PASS")
                Qt.quit()
                return
            }
            phase++
            restart()
        }
    }
'''
        self.assertEqual(self.check_menu(checks, helper), ["reboot"])

    def test_missing_helper_clears_pending_states(self):
        checks = '''
    Component.onCompleted: power.refreshActions()
    Timer {
        property int phase: 0
        interval: 300; running: true
        onTriggered: {
            if (phase === 0) {
                check(!power.resolving, "Resolution stuck after failed start")
                check(power.errorMessage.indexOf("Could not start mori-power") >= 0, "Missing helper not reported")
                power.resolvedActions = {reboot: {command: ["mock"], error: ""}}
                power.runAction({action: "reboot"})
                phase++
                restart()
            } else {
                check(!power.actionPending, "Action stuck after failed start")
                check(power.errorMessage.indexOf("Could not start the action") >= 0, "Failed start not reported")
                console.log("MORI_QML_CHECK_PASS")
                Qt.quit()
            }
        }
    }
'''
        self.assertEqual(self.check_menu(checks), [])


if __name__ == "__main__":
    unittest.main()
