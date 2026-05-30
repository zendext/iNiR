import QtQuick
import qs.modules.common

// Leading (idx1) / following (idx2) indicator edges. The leading edge is faster, so the body
// stretches toward the target during travel and contracts on arrival. Velocity-based
// (SmoothedAnimation): momentum carries through a mid-flight target change. idx1Duration/
// idx2Duration are kept as the API and translated to an equivalent velocity.
QtObject {
    id: root
    required property int index

    property real idx1: index
    property real idx2: index

    property int idx1Duration: 100
    property int idx2Duration: 300

    readonly property real _idx1Velocity: 1000 / Math.max(1, root.idx1Duration)
    readonly property real _idx2Velocity: 1000 / Math.max(1, root.idx2Duration)

    Behavior on idx1 {
        enabled: Appearance.animationsEnabled
        SmoothedAnimation { velocity: root._idx1Velocity }
    }
    Behavior on idx2 {
        enabled: Appearance.animationsEnabled
        SmoothedAnimation { velocity: root._idx2Velocity }
    }
}
