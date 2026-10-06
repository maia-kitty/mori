"""Extract actual QML controls for checks without a Wayland window backend."""
import re


def block(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth, quote, i = 0, None, opening
    while i < len(source):
        char = source[i]
        if quote:
            if char == '\\':
                i += 2
                continue
            if char == quote:
                quote = None
        elif char in '\"\'`':
            quote = char
        elif source.startswith('//', i):
            i = source.index('\n', i)
            continue
        elif source.startswith('/*', i):
            i = source.index('*/', i) + 2
            continue
        elif char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return source[start:i + 1]
        i += 1
    raise ValueError('Unbalanced QML block')


def object_with_id(source, type_name, identifier):
    marker = re.search(r'\b' + type_name + r'\s*\{\s*id:\s*' + identifier + r'\b', source)
    if marker is None:
        raise ValueError(f'Missing {identifier}')
    return block(source, marker.group())


def headless_settings(source):
    logic = source.split('    Component {\n        id: moduleSettingDelegate', 1)[0]
    delegate = object_with_id(source, 'Component', 'moduleSettingDelegate')
    scope = object_with_id(source, 'FocusScope', 'keyboardScope')
    card = object_with_id(source, 'Rectangle', 'settingsCard')
    return logic + delegate + '''
    Item {
        id: settingsWindow
        width: 800; height: 800; visible: false
''' + scope + card + '''
    }
    function testOpen(name) { settingsWindow.visible = true; openPage(name) }
    function testSelect(name) { settingsWindow.visible = true; page = name }
    function testInputEditor() { return keyboardLayoutEditor() }
    function testField(index) { return powerRows.itemAt(index).editor }
    function testPageCount() {
        return [homePage, modulesPage, appearancePage, clockPage,
            powerPage, inputPage, displaysPage, aboutPage]
            .filter(loader => loader.item !== null).length
    }
}\n'''
