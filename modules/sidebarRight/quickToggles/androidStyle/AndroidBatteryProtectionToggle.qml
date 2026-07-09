import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services

AndroidQuickToggleButton {
    id: root

    name: Translation.tr("Battery Protection")
    toggled: Config.options?.battery?.chargeLimit?.enable ?? false
    enabled: Battery.chargeLimitSupported && !Battery.chargeLimitBusy
    buttonIcon: toggled ? "battery_saver" : "battery_full"
    statusText: !Battery.chargeLimitSupported
        ? Translation.tr("Unsupported")
        : toggled
            ? Translation.tr("Limit %1").arg(Battery.chargeLimitStartSupported
                ? `${Config.options?.battery?.chargeLimit?.startThreshold ?? 60}/${Config.options?.battery?.chargeLimit?.threshold ?? 80}`
                : `${Config.options?.battery?.chargeLimit?.threshold ?? 80}`)
            : Translation.tr("Full charge")

    mainAction: () => {
        if (!Battery.chargeLimitSupported || Battery.chargeLimitBusy) return;
        Config.setNestedValue("battery.chargeLimit.enable", !(Config.options?.battery?.chargeLimit?.enable ?? false));
    }

    StyledToolTip {
        text: Battery.chargeLimitSupported
            ? Translation.tr("Battery protection\nCurrent: %1\nClick to toggle").arg(Battery.chargeLimitModeText)
            : Translation.tr("Battery protection unsupported")
    }
}
