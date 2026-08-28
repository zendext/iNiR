pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property bool available: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
    // Discharging-based, not !isPluggedIn: FullyCharged on AC must not count as "on battery"
    readonly property bool onBattery: available && (chargeState == UPowerDeviceState.Discharging || chargeState == UPowerDeviceState.PendingDischarge)
    property real percentage: UPower.displayDevice?.percentage ?? 1
    readonly property bool allowAutomaticSuspend: Config.options?.battery?.automaticSuspend ?? false
    readonly property bool soundEnabled: Config.options?.sounds?.battery ?? true

    property bool isLow: available && (percentage <= ((Config.options?.battery?.low ?? 20) / 100))
    property bool isCritical: available && (percentage <= ((Config.options?.battery?.critical ?? 10) / 100))
    property bool isSuspending: available && (percentage <= ((Config.options?.battery?.suspend ?? 5) / 100))
    property bool isFull: available && (percentage >= ((Config.options?.battery?.full ?? 95) / 100))

    property bool isLowAndNotCharging: isLow && !isCharging
    property bool isCriticalAndNotCharging: isCritical && !isCharging
    property bool isSuspendingAndNotCharging: allowAutomaticSuspend && isSuspending && !isCharging
    property bool isFullAndCharging: isFull && isCharging

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToEmpty: UPower.displayDevice.timeToEmpty
    property real timeToFull: UPower.displayDevice.timeToFull

    // ─── Charge limit ───
    readonly property bool chargeLimitEnabled: Config.options?.battery?.chargeLimit?.enable ?? false
    readonly property int chargeLimitStartThreshold: Config.options?.battery?.chargeLimit?.startThreshold ?? 60
    readonly property int chargeLimitThreshold: Config.options?.battery?.chargeLimit?.threshold ?? 80
    property string _chargeLimitBackend: ""
    property string _chargeLimitSysfsPath: ""
    property string _chargeLimitStartSysfsPath: ""
    property string _chargeLimitBehaviourSysfsPath: ""
    property int _rawChargeLimitValue: -1
    property int _currentChargeLimitStart: -1
    property string _currentChargeLimitBehaviour: ""
    property int _pendingChargeLimitAction: -1 // -1 none, 0 disable, 1 enable
    property int _currentChargeLimit: -1
    property bool _chargeLimitActive: false
    readonly property bool chargeLimitSupported: _chargeLimitBackend.length > 0 && _chargeLimitSysfsPath.length > 0
    readonly property bool chargeLimitStartSupported: _chargeLimitBackend === "threshold" && _chargeLimitStartSysfsPath.length > 0
    readonly property bool chargeLimitAdjustable: _chargeLimitBackend === "threshold"
        || _chargeLimitBackend === "smapi"
        || _chargeLimitBackend === "sony"
        || _chargeLimitBackend === "huawei"
    readonly property bool chargeLimitActive: _chargeLimitActive
    readonly property bool chargeLimitBusy: chargeLimitWriter.running || chargeLimitResetter.running || chargeLimitReader.running
    readonly property int currentChargeLimitStart: _currentChargeLimitStart
    readonly property int currentChargeLimit: _currentChargeLimit
    readonly property string chargeLimitModeText: chargeLimitStartSupported
        ? `${_currentChargeLimitStart}/${_currentChargeLimit}`
        : `${_currentChargeLimit}`

    Component.onCompleted: {
        if (root.available) {
            _detectChargeLimitPath()
        }
    }

    onAvailableChanged: {
        if (available && _chargeLimitSysfsPath.length === 0) {
            _detectChargeLimitPath()
        }
    }

    function _detectChargeLimitPath(): void {
        if (!chargeLimitDetector.running) {
            chargeLimitDetector.running = true
        }
    }

    Process {
        id: chargeLimitDetector
        command: ["/bin/sh", "-c",
            "for dir in /sys/class/power_supply/*; do " +
            "[ -d \"$dir\" ] || continue; " +
            "[ \"$(cat \"$dir/type\" 2>/dev/null)\" = \"Battery\" ] || continue; " +
            "if [ -f \"$dir/present\" ] && [ \"$(cat \"$dir/present\" 2>/dev/null)\" = \"0\" ]; then continue; fi; " +
            "start_path=''; behaviour_path=''; " +
            "for attr in charge_control_start_threshold charge_start_threshold; do [ -f \"$dir/$attr\" ] && start_path=\"$dir/$attr\" && break; done; " +
            "[ -f \"$dir/charge_behaviour\" ] && behaviour_path=\"$dir/charge_behaviour\"; " +
            "for attr in charge_control_end_threshold charge_stop_threshold; do " +
            "[ -f \"$dir/$attr\" ] && printf 'threshold|%s|%s|%s\\n' \"$dir/$attr\" \"$start_path\" \"$behaviour_path\" && exit 0; " +
            "done; " +
            "done; " +
            "for p in /sys/devices/platform/smapi/BAT*/stop_charge_thresh; do [ -f \"$p\" ] && printf 'smapi|%s\\n' \"$p\" && exit 0; done; " +
            "for p in /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode; do [ -f \"$p\" ] && printf 'ideapad|%s\\n' \"$p\" && exit 0; done; " +
            "[ -f /sys/devices/platform/lg-laptop/battery_care_limit ] && printf 'lg-legacy|%s\\n' /sys/devices/platform/lg-laptop/battery_care_limit && exit 0; " +
            "[ -f /sys/devices/platform/samsung/battery_life_extender ] && printf 'samsung|%s\\n' /sys/devices/platform/samsung/battery_life_extender && exit 0; " +
            "[ -f /sys/devices/platform/sony-laptop/battery_care_limiter ] && printf 'sony|%s\\n' /sys/devices/platform/sony-laptop/battery_care_limiter && exit 0; " +
            "[ -f /sys/devices/platform/huawei-wmi/charge_control_thresholds ] && printf 'huawei|%s\\n' /sys/devices/platform/huawei-wmi/charge_control_thresholds && exit 0; " +
            "printf '\\n'"
        ]
        stdout: SplitParser {
            onRead: data => {
                const result = data.trim()
                if (result.length > 0) {
                    const parts = result.split("|")
                    root._chargeLimitBackend = parts[0] ?? ""
                    root._chargeLimitSysfsPath = parts[1] ?? ""
                    root._chargeLimitStartSysfsPath = parts[2] ?? ""
                    root._chargeLimitBehaviourSysfsPath = parts[3] ?? ""
                    _log("[Battery] Charge limit backend: " + root._chargeLimitBackend + " (" + root._chargeLimitSysfsPath + ")")
                    root._readChargeLimit()
                }
            }
        }
    }

    // Reconcile only after the initial sysfs read. This avoids asking polkit to
    // write a value the firmware already has.
    Timer {
        id: chargeLimitApplyDelay
        interval: 250
        repeat: false
        onTriggered: {
            if (root.chargeLimitEnabled)
                root._applyChargeLimit()
        }
    }

    function _readChargeLimit(): void {
        if (_chargeLimitSysfsPath.length === 0 || chargeLimitReader.running) return
        if (_chargeLimitBackend === "threshold" && _chargeLimitStartSysfsPath.length > 0) {
            chargeLimitReader.command = [
                "/bin/sh", "-c",
                "printf 'start=%s\\n' \"$(cat \"$2\" 2>/dev/null)\"; " +
                "[ -n \"$3\" ] && printf 'behaviour=%s\\n' \"$(cat \"$3\" 2>/dev/null)\"; " +
                "printf 'end=%s\\n' \"$(cat \"$1\" 2>/dev/null)\"",
                "battery-charge-limit",
                _chargeLimitSysfsPath,
                _chargeLimitStartSysfsPath,
                _chargeLimitBehaviourSysfsPath,
            ]
        } else {
            chargeLimitReader.command = ["/bin/cat", _chargeLimitSysfsPath]
        }
        chargeLimitReader.running = true
    }

    function _updateChargeLimitState(rawValue: int): void {
        switch (_chargeLimitBackend) {
        case "ideapad":
            _chargeLimitActive = rawValue === 1
            _currentChargeLimit = rawValue === 0 ? 100 : -1
            break
        case "samsung":
            _chargeLimitActive = rawValue === 1
            _currentChargeLimit = rawValue === 1 ? 80 : 100
            break
        case "threshold":
            _chargeLimitActive = (_currentChargeLimitStart > 0) || (rawValue > 0 && rawValue < 100)
            _currentChargeLimit = rawValue
            break
        default:
            _chargeLimitActive = rawValue > 0 && rawValue < 100
            _currentChargeLimit = rawValue
            break
        }
    }

    function _normalizedChargeLimitThreshold(): int {
        if (_chargeLimitBackend === "sony") {
            if (chargeLimitThreshold <= 65) return 50
            if (chargeLimitThreshold <= 90) return 80
            return 100
        }

        return chargeLimitThreshold
    }

    function _desiredChargeLimitValue(enable: bool): int {
        switch (_chargeLimitBackend) {
        case "ideapad":
        case "samsung":
            return enable ? 1 : 0
        case "lg-legacy":
            return enable ? 80 : 100
        default:
            return enable ? _normalizedChargeLimitThreshold() : 100
        }
    }

    function _chargeLimitMatches(enable: bool): bool {
        if (_rawChargeLimitValue < 0)
            return false
        if (chargeLimitStartSupported) {
            const desiredStart = enable ? chargeLimitStartThreshold : 0
            const behaviourMatches = _chargeLimitBehaviourSysfsPath.length === 0
                || _currentChargeLimitBehaviour === "auto"
            return _currentChargeLimitStart === desiredStart
                && _rawChargeLimitValue === _desiredChargeLimitValue(enable)
                && behaviourMatches
        }
        return _rawChargeLimitValue === _desiredChargeLimitValue(enable)
    }

    function _buildChargeLimitWriteCommand(enable: bool): var {
        switch (_chargeLimitBackend) {
        case "ideapad":
        case "samsung":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        case "lg-legacy":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        case "huawei":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s %s' \"$1\" \"$2\" > \"$3\"",
                "battery-charge-limit",
                "0",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        case "threshold":
            if (_chargeLimitStartSysfsPath.length > 0) {
                return [
                    "/usr/bin/pkexec", "/bin/sh", "-c",
                    "start=\"$1\"; end=\"$2\"; end_path=\"$3\"; start_path=\"$4\"; behaviour_path=\"$5\"; " +
                    "current_end=\"$(cat \"$end_path\" 2>/dev/null || printf 100)\"; " +
                    "if [ \"$current_end\" -gt \"$start\" ]; then " +
                    "printf '%s' \"$start\" > \"$start_path\" && printf '%s' \"$end\" > \"$end_path\"; " +
                    "else " +
                    "printf '%s' \"$end\" > \"$end_path\" && printf '%s' \"$start\" > \"$start_path\"; " +
                    "fi; " +
                    "[ -n \"$behaviour_path\" ] && printf '%s' auto > \"$behaviour_path\" || true",
                    "battery-charge-limit",
                    enable ? String(chargeLimitStartThreshold) : "0",
                    String(_desiredChargeLimitValue(enable)),
                    _chargeLimitSysfsPath,
                    _chargeLimitStartSysfsPath,
                    _chargeLimitBehaviourSysfsPath,
                ]
            }
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        case "smapi":
        case "sony":
            return [
                "/usr/bin/pkexec", "/bin/sh", "-c",
                "printf '%s' \"$1\" > \"$2\"",
                "battery-charge-limit",
                String(_desiredChargeLimitValue(enable)),
                _chargeLimitSysfsPath,
            ]
        default:
            return []
        }
    }

    Process {
        id: chargeLimitReader
        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim()
                if (_chargeLimitBackend === "threshold" && trimmed.includes("=")) {
                    const index = trimmed.indexOf("=")
                    const key = trimmed.slice(0, index)
                    const value = trimmed.slice(index + 1)
                    if (key === "start") {
                        const start = parseInt(value)
                        if (!isNaN(start))
                            root._currentChargeLimitStart = start
                    } else if (key === "behaviour") {
                        const selected = value.match(/\[([^\]]+)\]/)
                        root._currentChargeLimitBehaviour = selected?.[1] ?? value.split(/\s+/)[0] ?? ""
                    } else if (key === "end") {
                        const end = parseInt(value)
                        if (!isNaN(end))
                            root._recordChargeLimitRead(end)
                    }
                    return
                }

                const val = _chargeLimitBackend === "huawei"
                    ? parseInt(trimmed.split(/\s+/).slice(-1)[0])
                    : parseInt(trimmed)

                if (!isNaN(val))
                    root._recordChargeLimitRead(val)
            }
        }
    }

    function _recordChargeLimitRead(rawValue: int): void {
        const initialRead = root._rawChargeLimitValue < 0
        root._rawChargeLimitValue = rawValue
        root._updateChargeLimitState(rawValue)
        const pendingAction = root._pendingChargeLimitAction
        if (pendingAction >= 0) {
            root._pendingChargeLimitAction = -1
            Qt.callLater(() => {
                if (pendingAction === 1)
                    root._applyChargeLimit()
                else
                    root._resetChargeLimit()
            })
        } else if (initialRead && root.chargeLimitEnabled) {
            chargeLimitApplyDelay.restart()
        }
    }

    // Periodically re-read the threshold so the UI stays in sync
    Timer {
        id: chargeLimitPoll
        interval: 30000
        repeat: true
        running: root.chargeLimitSupported
        onTriggered: root._readChargeLimit()
    }

    function _applyChargeLimit(): void {
        if (!chargeLimitSupported) return
        if (chargeLimitWriter.running || chargeLimitResetter.running) {
            _pendingChargeLimitAction = 1
            return
        }
        if (_rawChargeLimitValue < 0) {
            _pendingChargeLimitAction = 1
            _readChargeLimit()
            return
        }
        if (_chargeLimitMatches(true)) {
            _pendingChargeLimitAction = -1
            _log("[Battery] Charge limit already applied")
            return
        }
        _pendingChargeLimitAction = -1
        const command = _buildChargeLimitWriteCommand(true)
        if (command.length === 0) return
        chargeLimitWriter.command = command
        chargeLimitWriter.running = true
    }

    function _resetChargeLimit(): void {
        if (!chargeLimitSupported) return
        if (chargeLimitWriter.running || chargeLimitResetter.running) {
            _pendingChargeLimitAction = 0
            return
        }
        if (_rawChargeLimitValue < 0) {
            _pendingChargeLimitAction = 0
            _readChargeLimit()
            return
        }
        if (_chargeLimitMatches(false)) {
            _pendingChargeLimitAction = -1
            _log("[Battery] Charge limit already removed")
            return
        }
        _pendingChargeLimitAction = -1
        const command = _buildChargeLimitWriteCommand(false)
        if (command.length === 0) return
        chargeLimitResetter.command = command
        chargeLimitResetter.running = true
    }

    Process {
        id: chargeLimitWriter
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._readChargeLimit()
                _log("[Battery] Charge limit applied")
            } else {
                root._pendingChargeLimitAction = -1
                console.warn("[Battery] Failed to set charge limit (exit code " + exitCode + ")")
            }
        }
    }

    Process {
        id: chargeLimitResetter
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._readChargeLimit()
                _log("[Battery] Charge limit removed")
            } else {
                root._pendingChargeLimitAction = -1
                console.warn("[Battery] Failed to reset charge limit (exit code " + exitCode + ")")
            }
        }
    }

    onChargeLimitEnabledChanged: {
        if (!chargeLimitSupported) return
        chargeLimitApplyDelay.stop()
        if (chargeLimitEnabled) {
            _applyChargeLimit()
        } else {
            _resetChargeLimit()
        }
    }

    onChargeLimitThresholdChanged: {
        if (!chargeLimitSupported || !chargeLimitEnabled || !chargeLimitAdjustable) return
        _applyChargeLimit()
    }

    onChargeLimitStartThresholdChanged: {
        if (!chargeLimitStartSupported || !chargeLimitEnabled) return
        _applyChargeLimit()
    }

    // ─── Battery warnings ───
    onIsLowAndNotChargingChanged: {
        if (!root.available || !isLowAndNotCharging) return;
        Quickshell.execDetached([
            "/usr/bin/notify-send", 
            Translation.tr("Low battery"), 
            Translation.tr("Consider plugging in your device"), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ])

        if (root.soundEnabled) Audio.playEvent("batteryLow");
    }

    onIsCriticalAndNotChargingChanged: {
        if (!root.available || !isCriticalAndNotCharging) return;
        Quickshell.execDetached([
            "/usr/bin/notify-send", 
            Translation.tr("Critically low battery"), 
            Translation.tr("Please charge!\nAutomatic suspend triggers at %1%").arg(Config.options?.battery?.suspend ?? 5), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playEvent("batteryCritical");
    }

    onIsSuspendingAndNotChargingChanged: {
        if (root.available && isSuspendingAndNotCharging) {
            Session.suspend()
        }
    }

    onIsFullAndChargingChanged: {
        if (!root.available || !isFullAndCharging) return;
        Quickshell.execDetached([
            "/usr/bin/notify-send",
            Translation.tr("Battery full"),
            Translation.tr("Please unplug the charger"),
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playEvent("batteryFull");
    }

    onIsPluggedInChanged: {
        if (!root.available || !root.soundEnabled) return;
        if (isPluggedIn) {
            Audio.playEvent("powerPlug")
        } else {
            Audio.playEvent("powerUnplug")
        }
    }
}
