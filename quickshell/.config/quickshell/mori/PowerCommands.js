.pragma library

function valid(command) {
    return Array.isArray(command) && command.length > 0
        && command.every(value => typeof value === "string"
            && value.length > 0 && value.indexOf("\u0000") < 0)
}

// Split a command into literal arguments without evaluating shell syntax.
function parse(text) {
    if (text.indexOf("\u0000") >= 0)
        throw new Error("Commands cannot contain a NUL character.")
    const args = []
    let token = ""
    let started = false
    let quote = ""
    for (let i = 0; i < text.length; ++i) {
        const ch = text[i]
        if (quote === "'") {
            if (ch === "'") quote = ""
            else token += ch
        } else if (ch === "\\") {
            if (i + 1 === text.length)
                throw new Error("Finish the escaped character.")
            const next = text[++i]
            if (quote === '"' && ['"', "\\", "$", "`", "\n"].indexOf(next) < 0)
                token += "\\"
            if (next !== "\n") {
                token += next
                started = true
            }
        } else if (quote === '"') {
            if (ch === '"') quote = ""
            else token += ch
        } else if (ch === "'" || ch === '"') {
            quote = ch
            started = true
        } else if (/\s/.test(ch)) {
            if (started) {
                args.push(token)
                token = ""
                started = false
            }
        } else {
            token += ch
            started = true
        }
    }
    if (quote)
        throw new Error("Close the quoted argument.")
    if (started)
        args.push(token)
    if (args.some(value => value.length === 0))
        throw new Error("Command arguments cannot be empty.")
    return args
}

function format(command) {
    if (!valid(command))
        throw new Error("Use a command followed by its arguments.")
    return command.map(value => /^[a-zA-Z0-9_@%+=:,./-]+$/.test(value)
        ? value : "'" + value.split("'").join("'\\''") + "'").join(" ")
}
