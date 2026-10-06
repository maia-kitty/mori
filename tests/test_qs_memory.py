"""Check actual QML object lifetimes and bounded notification history."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from qml_helpers import object_with_id
import test_power_settings

SOURCE = Path(__file__).resolve().parents[1] / 'quickshell/.config/quickshell/mori'


@unittest.skipUnless(shutil.which('qs'), 'Quickshell is required')
class MemoryTests(unittest.TestCase):
    def run_qml(self, component, checks, properties=''):
        with tempfile.TemporaryDirectory(prefix='mori-memory-') as tmp:
            base = Path(tmp)
            shutil.copytree(SOURCE, base / 'mori')
            (base / 'mori/Subject.qml').write_text(component)
            (base / 'run').mkdir(mode=0o700)
            (base / 'bin').mkdir()
            (base / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "mori" as Mori
ShellRoot {
    Mori.Subject { id: subject; ''' + properties + ''' }
    QtObject {
        id: coordinator
        signal notification(var notification)
        function showPopup(item) {}
        function hidePopup(item) {}
    }
    function check(condition, message) { if (!condition) throw new Error(message) }
''' + checks + '\n}\n')
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen',
                       XDG_RUNTIME_DIR=str(base / 'run'),
                       XDG_CONFIG_HOME=str(base / 'config'),
                       XDG_CACHE_HOME=str(base / 'cache'), PATH=str(base / 'bin'))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run([shutil.which('qs'), '--path', str(base / 'shell.qml'), '--no-color'],
                                    env=env, text=True, capture_output=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('MORI_MEMORY_PASS', output)
            for error in ('ReferenceError', 'TypeError', 'Binding loop', 'Unable to assign'):
                self.assertNotIn(error, output)

    def popup_component(self, name, popup='popup'):
        source = (SOURCE / (name + '.qml')).read_text()
        prefix = source.split('    PopupWindow {', 1)[0]
        loader = object_with_id(source, 'Loader', 'popupContent')
        return prefix + '''
    Item {
        id: ''' + popup + '''
        visible: false; width: 360; height: 440
''' + loader + '''
    }
    function testOpen() { ''' + popup + '''.visible = true }
    function testLoaded() { return popupContent.item !== null }
    function testVisualCount() {
        function count(item) {
            return 1 + item.children.reduce((total, child) => total + count(child), 0)
        }
        return popupContent.item ? count(popupContent.item) : 0
    }
}\n'''

    def test_popups_release_contents_and_reopen(self):
        for name, popup in [('Calendar', 'popup'), ('Network', 'popup'), ('Volume', 'devicePopup')]:
            with self.subTest(module=name):
                props = 'panelWindow: coordinator; popupCoordinator: coordinator'
                if name == 'Calendar':
                    props += '; settings: ({clockShowSeconds:false, clockDateFormat:"yyyy-MM-dd", clockTimeFormat:"24h"})'
                self.run_qml(self.popup_component(name, popup), '''
    Timer {
        interval: 100; running: true
        onTriggered: {
            check(!subject.testLoaded(), "Closed popup created visuals")
            for (let i = 0; i < 3; i++) {
                subject.testOpen()
                check(subject.testLoaded(), "Open popup missing visuals")
                check(subject.testVisualCount() > 5, "Popup contents missing")
                subject.close()
                check(!subject.testLoaded(), "Closed popup retained visuals")
            }
            console.log("MORI_MEMORY_PASS"); Qt.quit()
        }
    }
''', props)

    def test_audio_delegates_filter_and_unload(self):
        source = (SOURCE / 'Volume.qml').read_text()
        delegate = object_with_id(source, 'Loader', 'nodeLoader')
        delegate = delegate.replace('required property var modelData', 'property var modelData: fakeNode')
        delegate = delegate.replace('required property int index', 'property int index: 0')
        imports = source.split('RowLayout {', 1)[0]
        component = imports + """
Item {
    id: root
    width: 320; height: 440
    property color accent: Theme.yellow
    property var sink: null
    property var keyboardNode: null
    function setVolume(node, value) { node.audio.volume = value }
    QtObject {
        id: fakeNode
        property bool ready: false
        property bool isSink: false
        property bool isStream: false
        property string description: "Test sink"
        property string nickname: ""
        property string name: "Test"
        property var audio: fakeAudio
    }
    QtObject { id: fakeAudio; property real volume: 0.5; property bool muted: false }
    ScrollableColumn {
        id: deviceList
        anchors.fill: parent
""" + delegate + """
    }
    function testLoaded() { return nodeLoader.item !== null }
    function testReady() { fakeNode.ready = true }
    function testSink(value) { fakeNode.isSink = value }
    function testStream(value) { fakeNode.isStream = value }
}
"""
        self.run_qml(component, """
    Timer {
        interval: 100; running: true
        onTriggered: {
            check(!subject.testLoaded(), "Unready node created controls")
            subject.testReady()
            check(!subject.testLoaded(), "Input node created output controls")
            subject.testSink(true)
            check(subject.testLoaded(), "Ready sink has no controls")
            subject.testStream(true)
            check(!subject.testLoaded(), "Stream retained output-device controls")
            subject.testStream(false)
            check(subject.testLoaded(), "Sink controls failed to reload")
            subject.testSink(false)
            check(!subject.testLoaded(), "Removed sink retained controls")
            console.log("MORI_MEMORY_PASS"); Qt.quit()
        }
    }
""")

    def test_notification_cap_virtualization_and_clear(self):
        source = self.popup_component('NotificationCenter')
        source = source.replace('    function testOpen()', '''    function testNewest() { return notificationHistory.get(0).summary }
    function testOldest() { return notificationHistory.get(notificationHistory.count - 1).summary }
    function testOpen()''')
        self.run_qml(source, '''
    Timer {
        property int phase: 0
        interval: 100; running: true
        onTriggered: {
            if (phase === 0) {
                for (let i = 0; i < 750; i++)
                    coordinator.notification({appName:"Test", summary:String(i), body:"Example body"})
                phase++; restart(); return
            }
            if (phase === 1) {
                subject.testOpen()
                phase++; restart(); return
            }
            check(subject.notificationCount === 500, "History exceeded cap")
            check(subject.testNewest() === "749" && subject.testOldest() === "250", "Wrong entries retained")
            check(subject.testVisualCount() > 20, "History did not create visible rows")
            check(subject.testVisualCount() < 250, "History eagerly created all 500 delegates")
            subject.close()
            check(!subject.testLoaded() && subject.notificationCount === 500, "Closing lost history or retained visuals")
            subject.testOpen()
            subject.handleKeyPressed({key:Qt.Key_C, modifiers:Qt.NoModifier, isAutoRepeat:false})
            check(subject.notificationCount === 0, "Clear shortcut failed")
            console.log("MORI_MEMORY_PASS"); Qt.quit()
        }
    }
''', 'panelWindow: coordinator; popupCoordinator: coordinator; notificationServer: coordinator')

    def test_settings_one_page_and_pending_close(self):
        runner = test_power_settings.PowerSettingsTests()
        runner.run_settings('''
    Timer {
        interval: 100; running: true
        onTriggered: {
            check(editor.testPageCount() === 0, "Closed settings created pages")
            for (const name of ["home", "modules", "appearance", "clock", "power", "about"]) {
                editor.testOpen(name)
                check(editor.testPageCount() === 1, "Multiple settings pages remain alive")
            }
            editor.keyboardLayoutDraft = "us,sk"
            editor.testSelect("input")
            check(editor.testInputEditor().text === "us,sk", "Input draft did not load")
            editor.testSelect("displays")
            check(editor.testPageCount() === 1 && editor.displayCanvas !== null, "Display page did not load")
            editor.fitDisplayLayout()
            editor.testSelect("input")
            check(editor.testInputEditor().text === "us,sk", "Page switch lost input draft")
            editor.inputApplyPending = true
            editor.close()
            check(editor.closeAfterApply && editor.inputApplyPending, "Closing discarded pending save")
            check(editor.testPageCount() === 0, "Pending save retained settings visuals")
            editor.inputApplyPending = false
            editor.finishDeferredClose()
            check(!editor.closeAfterApply, "Deferred close failed")
            console.log("MORI_SETTINGS_CHECK_PASS"); Qt.quit()
        }
    }
''')

    def test_shared_niri_json_events(self):
        self.run_qml((SOURCE / 'NiriEvents.qml').read_text(), '''
    property int workspaceEvents: 0
    Connections {
        target: subject
        function onWorkspacesChanged() { workspaceEvents++ }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            subject.readEvent('{"OverviewOpenedOrClosed":{"is_open":true}}')
            check(subject.overviewOpen, "Overview did not open")
            subject.readEvent('{"WorkspacesChanged":{"workspaces":[]}}')
            subject.readEvent('{"WorkspaceActivated":{"id":1,"focused":true}}')
            subject.readEvent('{"WorkspaceUrgencyChanged":{"id":1,"urgent":true}}')
            subject.readEvent('{"WindowClosed":{"id":1}}')
            check(workspaceEvents === 3, "Incorrect workspace event routing")
            subject.readEvent('{"OverviewOpenedOrClosed":{"is_open":false}}')
            check(!subject.overviewOpen, "Overview did not close")
            console.log("MORI_MEMORY_PASS"); Qt.quit()
        }
    }
''')
