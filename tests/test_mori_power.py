"""Power-menu routing tests; all power executables are temporary mocks."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "bin/.local/bin/mori-power"


class PowerRoutingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.config = self.root / "config/quickshell/mori-settings.json"
        self.config.parent.mkdir(parents=True)
        self.log = self.root / "command.json"
        self.runtime = self.root / "systemd"
        self.helper = self.root / "mori-power"
        source = HELPER.read_text()
        self.assertEqual(source.count("/run/systemd/system"), 1)
        # Only the runtime-directory probe is redirected. Production routing
        # and command execution are exercised unchanged, with an isolated PATH.
        self.helper.write_text(source.replace("/run/systemd/system", str(self.runtime)))
        jq = shutil.which("jq")
        self.assertIsNotNone(jq, "Tests require jq")
        (self.bin / "jq").symlink_to(jq)
        self.env = {
            "PATH": str(self.bin),
            "HOME": str(self.root / "home"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "MORI_TEST_LOG": str(self.log),
        }

    def mock(self, name, prelude=""):
        script = self.bin / name
        script.write_text(
            "#!/bin/sh\n" + prelude + "\n"
            'jq -cn --args \'$ARGS.positional\' -- "$0" "$@" > "$MORI_TEST_LOG"\n'
            'exit "${MORI_TEST_EXIT:-0}"\n'
        )
        script.chmod(0o755)
        return script

    def loginctl(self, reachable=True, power_verbs=True):
        verbs = "suspend reboot poweroff" if power_verbs else "list-sessions show-session"
        self.mock("loginctl", f'''case "$1" in
    --help) printf '%s\\n' '{verbs}'; exit 0 ;;
    list-sessions) exit {0 if reachable else 1} ;;
esac''')

    def run_helper(self, action="--resolve"):
        return subprocess.run(
            ["/bin/bash", str(self.helper), action], env=self.env,
            capture_output=True, text=True, timeout=5,
        )

    def resolve(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists(), "Resolution must not dispatch power actions")
        return json.loads(result.stdout)

    def overrides(self, value):
        self.config.write_text(json.dumps({"power": value}))

    def test_running_systemd_has_priority_over_elogind(self):
        self.runtime.mkdir()
        self.mock("systemctl")
        self.loginctl()
        actions = self.resolve()
        for name in ("suspend", "reboot", "poweroff"):
            self.assertEqual(actions[name]["command"], ["systemctl", name])

    def test_installed_systemctl_does_not_imply_running_systemd(self):
        self.mock("systemctl")
        self.loginctl()
        self.assertEqual(self.resolve()["suspend"]["command"], ["loginctl", "suspend"])

    def test_elogind_requires_reachable_manager(self):
        self.loginctl(reachable=False)
        self.mock("zzz")
        self.assertEqual(self.resolve()["suspend"]["command"], ["zzz"])

    def test_systemd_loginctl_is_not_an_elogind_backend(self):
        self.loginctl(power_verbs=False)
        self.mock("pm-suspend")
        self.assertEqual(self.resolve()["suspend"]["command"], ["pm-suspend"])

    def test_native_actions_and_suspend_precedence(self):
        for name in ("zzz", "pm-suspend", "reboot", "poweroff"):
            self.mock(name)
        actions = self.resolve()
        self.assertEqual(actions["suspend"]["command"], ["zzz"])
        self.assertEqual(actions["reboot"]["command"], ["reboot"])
        self.assertEqual(actions["poweroff"]["command"], ["poweroff"])

    def test_missing_actions_resolve_independently(self):
        self.mock("reboot")
        actions = self.resolve()
        self.assertEqual(actions["reboot"]["command"], ["reboot"])
        for name in ("suspend", "poweroff"):
            self.assertEqual(actions[name]["command"], [])
            self.assertIn(str(self.config), actions[name]["error"])

    def test_override_precedence_and_literal_arguments(self):
        self.runtime.mkdir()
        self.mock("systemctl")
        wrapper = self.mock("custom-suspend")
        args = [str(wrapper), "two words", "line\nbreak", "$(poweroff)", "`reboot`"]
        self.overrides({"suspend": args})
        actions = self.resolve()
        self.assertEqual(actions["suspend"]["command"], args)
        self.assertEqual(actions["reboot"]["command"], ["systemctl", "reboot"])
        result = self.run_helper("suspend")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.log.read_text()), args)

    def test_bad_override_disables_only_its_action(self):
        self.mock("reboot")
        for bad in ([], "zzz", ["zzz", 1], [""], ["zzz", ""], ["zzz\u0000"]):
            with self.subTest(value=bad):
                self.overrides({"suspend": bad})
                actions = self.resolve()
                self.assertEqual(actions["suspend"]["command"], [])
                self.assertIn("Invalid suspend override", actions["suspend"]["error"])
                self.assertEqual(actions["reboot"]["command"], ["reboot"])

    def test_override_flags_are_preserved_during_resolution_and_execution(self):
        self.mock("sudo")
        self.mock("loginctl", 'case "$1" in --help) exit 0 ;; esac')
        self.mock("wrapper")
        for args in (
            ["sudo", "-n", "systemctl", "poweroff"],
            ["loginctl", "--no-ask-password", "suspend"],
            ["wrapper", "--", "--args", "--arg", "-n"],
        ):
            with self.subTest(command=args):
                self.log.unlink(missing_ok=True)
                self.overrides({"poweroff": args})
                self.assertEqual(self.resolve()["poweroff"]["command"], args)
                result = self.run_helper("poweroff")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    json.loads(self.log.read_text()),
                    [str(self.bin / args[0]), *args[1:]],
                )

    def test_unavailable_override_does_not_fall_back(self):
        self.mock("zzz")
        self.overrides({"suspend": ["missing-wrapper"]})
        self.assertEqual(self.resolve()["suspend"]["command"], [])
        result = self.run_helper("suspend")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing-wrapper", result.stderr)
        self.assertFalse(self.log.exists())

    def test_malformed_config_is_reported_without_dispatch(self):
        self.mock("zzz")
        for bad in ("", "[]", "{", "{}\n{}", "null"):
            with self.subTest(value=bad):
                self.config.write_text(bad)
                result = self.run_helper("suspend")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(str(self.config), result.stderr)
                self.assertFalse(self.log.exists())

    def test_permission_failure_is_reported_without_retry(self):
        self.runtime.mkdir()
        systemctl = self.mock("systemctl")
        self.loginctl()
        self.mock("zzz")
        self.env["MORI_TEST_EXIT"] = "7"
        result = self.run_helper("suspend")
        self.assertEqual(result.returncode, 7)
        self.assertIn("Check permissions", result.stderr)
        self.assertEqual(json.loads(self.log.read_text()), [str(systemctl), "suspend"])

    def test_config_home_falls_back_to_home(self):
        self.env.pop("XDG_CONFIG_HOME")
        config = Path(self.env["HOME"]) / ".config/quickshell/mori-settings.json"
        config.parent.mkdir(parents=True)
        self.mock("my-wrapper")
        config.write_text('{"power": {"poweroff": ["my-wrapper"]}}')
        self.assertEqual(self.resolve()["poweroff"]["command"], ["my-wrapper"])

    def test_settings_without_power_overrides_keep_automatic_selection(self):
        self.mock("zzz")
        self.config.write_text('{"modules": {"powerMenu": true}, "clock": {"timeFormat": "12h"}}')
        self.assertEqual(self.resolve()["suspend"]["command"], ["zzz"])

    def test_power_section_must_be_an_object(self):
        for bad in ([], None, "zzz", False):
            with self.subTest(value=bad):
                self.overrides(bad)
                result = self.run_helper()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("power object", result.stderr)

    def test_no_tools_reports_every_action_unavailable(self):
        self.assertTrue(all(not action["command"] for action in self.resolve().values()))

    def test_invalid_action_never_dispatches(self):
        self.mock("poweroff")
        result = self.run_helper("hibernate")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Usage", result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
