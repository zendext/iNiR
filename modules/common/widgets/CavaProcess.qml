pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.services.deferred
import qs.modules.common

// Thin wrapper for backwards compatibility. All consumers historically
// instantiated their own CavaProcess { active: ...; points }, which spawned
// a subprocess per consumer. The actual cava lifecycle now lives in
// services/CavaService.qml — see #160.
//
// This component just subscribes/unsubscribes on `active` and exposes the
// shared points list. Same external API.
Item {
    id: root

    property bool active: false
    readonly property var points: CavaService.points

    readonly property bool _wanted: active && !Appearance.gameModeMinimal
    property bool _held: false

    function _reconcile(): void {
        if (_wanted === _held)
            return
        if (_wanted) CavaService.subscribe()
        else CavaService.unsubscribe()
        _held = _wanted
    }

    on_WantedChanged: root._reconcile()
    Component.onCompleted: root._reconcile()

    Component.onDestruction: {
        if (_held) CavaService.unsubscribe()
    }
}
