.pragma library

var compactScreenWidth = 1800

function moduleAllowedAtWidth(moduleId, screenWidth) {
    if (!(screenWidth > 0 && screenWidth <= compactScreenWidth))
        return true
    return moduleId !== "media" && moduleId !== "weather"
}
