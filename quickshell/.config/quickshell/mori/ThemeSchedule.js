.pragma library

// Sunrise and sunset in minutes after local midnight (NOAA approximation,
// about a minute of error). Returns { polar: "day" | "night" } when the sun
// doesn't cross the horizon that day.
function sunTimes(date, latitude, longitude) {
    const rad = Math.PI / 180
    const dayOfYear = Math.round((new Date(date.getFullYear(), date.getMonth(), date.getDate())
        - new Date(date.getFullYear(), 0, 1)) / 86400000)
    const g = 2 * Math.PI / 365 * dayOfYear
    const equationOfTime = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g)
        - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g))
    const declination = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g)
        - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g)
        - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g)
    const cosHourAngle = (Math.cos(90.833 * rad) - Math.sin(latitude * rad) * Math.sin(declination))
        / (Math.cos(latitude * rad) * Math.cos(declination))
    if (cosHourAngle > 1) return { polar: "night" }
    if (cosHourAngle < -1) return { polar: "day" }
    const hourAngle = Math.acos(cosHourAngle) / rad
    const noon = 720 - 4 * longitude - equationOfTime - date.getTimezoneOffset()
    return { rise: wrap(noon - 4 * hourAngle), set: wrap(noon + 4 * hourAngle) }
}

function wrap(minutes) {
    return ((Math.round(minutes) % 1440) + 1440) % 1440
}

// Whether `now` (minutes after midnight) falls in the light span [from, until).
function inSpan(now, from, until) {
    return from <= until ? now >= from && now < until : now >= from || now < until
}

// "light", "dark", or "" when the schedule is off.
function scheduledMode(settings, date) {
    const now = date.getHours() * 60 + date.getMinutes()
    if (settings.themeSchedule === "times")
        return inSpan(now, settings.themeLightTime, settings.themeDarkTime) ? "light" : "dark"
    if (settings.themeSchedule === "sun") {
        const sun = sunTimes(date, settings.themeLatitude, settings.themeLongitude)
        if (sun.polar) return sun.polar === "day" ? "light" : "dark"
        return inSpan(now, sun.rise, sun.set) ? "light" : "dark"
    }
    return ""
}

function formatMinutes(minutes) {
    const hours = Math.floor(minutes / 60)
    return (hours < 10 ? "0" : "") + hours + ":" + (minutes % 60 < 10 ? "0" : "") + minutes % 60
}
