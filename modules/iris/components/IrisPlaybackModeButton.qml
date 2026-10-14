pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.services
import qs.modules.iris.style

IrisIconButton {
    id: root
    required property var player
    property string mode: "repeat"
    readonly property bool supported: Boolean(root.player?.canControl
        && (root.mode === "shuffle" ? root.player.shuffleSupported : root.player.loopSupported))
    readonly property string caption: {
        if (root.mode === "shuffle")
            return root.selected ? Translation.tr("Shuffle On") : Translation.tr("Shuffle Off")
        if (root.player?.loopState === MprisLoopState.Track) return Translation.tr("Repeat One")
        if (root.player?.loopState === MprisLoopState.Playlist) return Translation.tr("Repeat All")
        return Translation.tr("Repeat Off")
    }

    visible: root.supported
    enabled: root.supported
    selected: root.mode === "shuffle" ? Boolean(root.player?.shuffle)
        : (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
    materialIcon: root.mode === "shuffle" ? "shuffle"
        : root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
    foreground: IrisStyle.text
    colBackgroundToggled: root.colBackground
    colBackgroundToggledHover: root.colBackgroundHover
    opacity: root.selected ? 1 : 0.45
    Accessible.name: root.caption
    Accessible.checkable: true

    onClicked: {
        if (!root.enabled || !root.supported) return
        if (root.mode === "shuffle") {
            root.player.shuffle = !root.player.shuffle
            return
        }
        switch (root.player.loopState) {
        case MprisLoopState.None:
            root.player.loopState = MprisLoopState.Playlist
            break
        case MprisLoopState.Playlist:
            root.player.loopState = MprisLoopState.Track
            break
        default:
            root.player.loopState = MprisLoopState.None
        }
    }
}
