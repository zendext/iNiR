import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    id: root

    toggled: Config.options?.battery?.chargeLimit?.enable ?? false
    enabled: Battery.chargeLimitSupported && !Battery.chargeLimitBusy
    buttonIcon: toggled ? "battery_saver" : "battery_full"

    onClicked: {
        if (!Battery.chargeLimitSupported || Battery.chargeLimitBusy) return;
        Config.setNestedValue("battery.chargeLimit.enable", !(Config.options?.battery?.chargeLimit?.enable ?? false));
    }

    StyledToolTip {
        text: Battery.chargeLimitSupported
            ? Translation.tr("Battery protection\nCurrent: %1\nClick to toggle").arg(Battery.chargeLimitModeText)
            : Translation.tr("Battery protection unsupported")
    }
}
