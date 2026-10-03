/// Canonical catalog of Zebra SGD (Set/Get/Do) keys.
///
/// Every entry below is verified by cross-referencing Zebra's own
/// shipping Printer Setup Utility (the SGD keys that app actually
/// references). Historical keys that
/// looked plausible but aren't actually referenced by Zebra's shipping
/// app (e.g. `usb.enable`, `usb.halt_on_boot`) are deliberately
/// omitted — they return `"?"` on ZQ620 firmware V85.20.24 and are
/// almost certainly absent on every other mobile Zebra, so including
/// them would just be noise in diagnostics.
///
/// Use this enum as the single source of truth for SGD key names.
/// Read with `printer.getSetting(key.value)`, write with
/// `! U1 setvar "${key.value}" "<val>"`, or invoke an action with
/// `! U1 do "${key.value}" "<arg>"` (only [SgdCategory.action] entries
/// support `do`).
///
/// Not all keys are available on all firmware or model lines. Desktop
/// printers (ZD/ZT series) and mobile printers (ZQ/QLn series) expose
/// different subsets. When a key is absent the printer returns `"?"`
/// to a `getvar`; read the doc comment on each entry for known
/// coverage notes.
library;

/// Top-level grouping for SGDs. Drives UI sections (Maintenance,
/// Wireless, etc.) and helps consumers reason about safety — e.g.
/// [SgdCategory.action] keys are `do`-style side effects and should
/// almost always be behind a confirmation dialog.
enum SgdCategory {
  /// Model, serial, firmware, Link-OS version.
  identity,

  /// USB descriptor / cable state.
  usb,

  /// Battery + power management settings.
  power,

  /// Print quality + media configuration (darkness, speed, label geometry).
  media,

  /// Bluetooth Classic / BLE admin.
  bluetooth,

  /// Wi-Fi radio + association + DHCP-client options.
  wifi,

  /// IP interface, active network, protocol service toggles (LPD, SNMP…).
  network,

  /// Lifetime counters: labels printed, head-clean intervals, etc.
  odometer,

  /// `do`-style action (reboot, calibrate, print config). Side effect.
  action,

  /// Diagnostic status keys (multi-line responses — handle with care on BLE).
  diagnostic,

  /// Security / admin / protected-mode gates.
  security,

  /// Anything that doesn't fit cleanly above.
  other,
}

/// Zebra SGD keys catalog. Entries are grouped by [SgdCategory] and
/// ordered alphabetically within each group.
enum PrinterSgdKey {
  // ── Identity ────────────────────────────────────────────────────

  /// Firmware application name/version string, e.g. `"V85.20.24"`.
  applName('appl.name', SgdCategory.identity),

  /// Link-OS version string. Used for feature detection — some SGDs
  /// only exist on Link-OS >= N. Return format is `"<major>.<minor>"`
  /// on supported firmware, `"?"` on pre-Link-OS.
  applLinkOsVersion('appl.link_os_version', SgdCategory.identity),

  /// Whether Bluetooth hardware is physically installed. Returns
  /// `"yes"` / `"no"`. Distinct from [bluetoothEnable] which controls
  /// the software radio state.
  deviceBluetoothInstalled('device.bluetooth_installed', SgdCategory.identity),

  /// User-editable friendly name shown in the printer menu and BLE
  /// GAP advertising. Writable.
  deviceFriendlyName('device.friendly_name', SgdCategory.identity),

  /// Internal device ID string.
  deviceId('device.id', SgdCategory.identity),

  /// Manufacturer string. Usually `"Zebra Technologies"`.
  deviceManufacturer('device.manufacturer', SgdCategory.identity),

  /// Model identifier code (short alphanumeric, e.g. `"ZQ620"`).
  deviceModelIdentifier('device.model.identifier', SgdCategory.identity),

  /// Human-readable model name (e.g. `"ZQ620"` or `"ZD421-203dpi CPCL"`).
  deviceModelName('device.model.name', SgdCategory.identity),

  /// Printhead DPI / resolution as an integer string (e.g. `"203"`).
  devicePrintheadResolution(
    'device.printhead.resolution',
    SgdCategory.identity,
  ),

  /// Product name string.
  deviceProductName('device.product_name', SgdCategory.identity),

  /// Stable printer serial number (factory-assigned). Persistent.
  /// This is the key to use for identity gating, not iSerialNumber
  /// descriptors (which can be blank or collide).
  deviceUniqueId('device.unique_id', SgdCategory.identity),

  /// Free-form printer description set by the administrator.
  infoDescription('info.description', SgdCategory.identity),

  // ── USB ─────────────────────────────────────────────────────────

  /// `"yes"` when the printer detects Vbus from a USB cable,
  /// regardless of whether the host has enumerated the device.
  /// **This does not prove the data lines work** — a charge-only
  /// cable will still return `"yes"`. Cross-check with host-side
  /// `ioreg`/`system_profiler` to verify enumeration completed.
  usbConnected('usb.connected', SgdCategory.usb),

  /// USB device version descriptor (bcdDevice), e.g. `"1.1"`.
  usbDeviceDeviceVersion('usb.device.device_version', SgdCategory.usb),

  /// USB iProduct descriptor string advertised to the host,
  /// e.g. `"ZTC ZQ620-203dpi CPCL"`.
  usbDeviceProductString('usb.device.product_string', SgdCategory.usb),

  /// USB iSerialNumber descriptor advertised to the host. On some
  /// ZQ firmwares this is just the model name (`"ZQ620"`), not the
  /// actual serial — use [deviceUniqueId] for identity.
  usbDeviceSerialString('usb.device.serial_string', SgdCategory.usb),

  /// USB mirror-mode toggle. When `"on"`, print streams sent over
  /// another interface are echoed to USB — used for capture/debug
  /// during development. Defaults to `"off"`.
  usbMirrorEnable('usb.mirror.enable', SgdCategory.usb),

  // ── Power / Battery ─────────────────────────────────────────────

  /// Charger status string (e.g. `"charging"`, `"charged"`, `"none"`).
  powerChargerStatus('power.charger_status', SgdCategory.power),

  /// Legacy alias / alternate capitalisation of [powerChargerStatus]
  /// present on some firmwares.
  powerChgrStatus('power.chgr_status', SgdCategory.power),

  /// Cradle-docked auto-shutdown timer (seconds / minutes,
  /// firmware-dependent). Writable.
  powerCradleShutdownTimeout(
    'power.cradle_shutdown_timeout',
    SgdCategory.power,
  ),

  /// Number of complete charge/discharge cycles the pack has seen.
  powerCycleCount('power.cycle_count', SgdCategory.power),

  /// Date the battery pack was first used by the printer.
  powerDateFirstUsed('power.date_first_used', SgdCategory.power),

  /// Pack design capacity in mAh.
  powerDesignCapacity('power.design_capacity', SgdCategory.power),

  /// Pack design voltage in mV.
  powerDesignVoltage('power.design_voltage', SgdCategory.power),

  /// Current usable pack capacity in mAh. Divide into
  /// [powerDesignCapacity] for state-of-health percentage.
  powerFullChargeCapacity('power.full_charge_capacity', SgdCategory.power),

  /// Pack health string (e.g. `"good"`, `"replace_soon"`).
  powerHealth('power.health', SgdCategory.power),

  /// Seconds of idle time before auto power-off. Writable.
  powerInactivityTimeout('power.inactivity_timeout', SgdCategory.power),

  /// Whether a queued label job prevents low-battery shutdown.
  /// Writable.
  powerLabelQueueShutdown('power.label_queue.shutdown', SgdCategory.power),

  /// Seconds before shutting down at critical battery level. Writable.
  powerLowBatteryTimeout('power.low_battery_timeout', SgdCategory.power),

  /// Battery pack manufacture date.
  powerManufactureDate('power.manufacture_date', SgdCategory.power),

  /// Battery percentage (0–100 as string).
  powerPercentFull('power.percent_full', SgdCategory.power),

  /// Printer power-on cycle count.
  powerPowerOnCycles('power.power_on_cycles', SgdCategory.power),

  /// Relative state-of-charge percentage (0–100).
  powerRelativeStateOfCharge(
    'power.relative_state_of_charge',
    SgdCategory.power,
  ),

  /// Battery pack serial number.
  powerSerialNumber('power.serial_number', SgdCategory.power),

  /// Top-level power subsystem status string.
  powerStatus('power.status', SgdCategory.power),

  // ── Media / Print quality ───────────────────────────────────────

  /// Print head darkness level / burn temperature. Integer-as-string,
  /// firmware-specific range (typically `0`–`30`). Writable.
  headDarknessSwitch('head.darkness_switch', SgdCategory.media),

  /// EZPL media type (`"label"`, `"journal"`, `"continuous"`, …).
  /// Writable.
  ezplMediaType('ezpl.media_type', SgdCategory.media),

  /// EZPL print method (`"thermal_trans"`, `"direct_thermal"`).
  /// Writable.
  ezplPrintMethod('ezpl.print_method', SgdCategory.media),

  /// EZPL / ZPL print width in dots. Writable. Used to size
  /// rasterised images correctly before sending.
  ezplPrintWidth('ezpl.print_width', SgdCategory.media),

  /// Media print mode (tear-off, peel, cutter, rewind, applicator).
  /// Writable.
  mediaPrintmode('media.printmode', SgdCategory.media),

  /// Media feed speed (inches per second, as string). Writable.
  mediaSpeed('media.speed', SgdCategory.media),

  /// Media type at the media-subsystem level (distinct from
  /// [ezplMediaType] — this one may expose RFID/linerless details on
  /// applicable printers). Writable.
  mediaType('media.type', SgdCategory.media),

  /// Tone-mapping format for image-mode prints. Writable.
  printToneFormat('print.tone_format', SgdCategory.media),

  /// Tone-mapping curve for ZPL-rasterised images. Writable.
  printToneZpl('print.tone_zpl', SgdCategory.media),

  /// ZPL label length in dots. Writable.
  zplLabelLength('zpl.label_length', SgdCategory.media),

  /// ZPL print orientation (`"N"` normal, `"I"` inverted). Writable.
  zplPrintOrientation('zpl.print_orientation', SgdCategory.media),

  // ── Bluetooth ───────────────────────────────────────────────────

  /// Bluetooth Classic MAC address of the printer.
  bluetoothAddress('bluetooth.address', SgdCategory.bluetooth),

  /// Current Bluetooth pairing PIN. Writable on firmwares that
  /// support static-PIN pairing.
  bluetoothBluetoothPin('bluetooth.bluetooth_pin', SgdCategory.bluetooth),

  /// Classic Bluetooth bonding mode / security policy. Writable.
  bluetoothBonding('bluetooth.bonding', SgdCategory.bluetooth),

  /// Classic Bluetooth discoverable flag. Writable.
  bluetoothDiscoverable('bluetooth.discoverable', SgdCategory.bluetooth),

  /// Master Bluetooth radio enable. Writable.
  bluetoothEnable('bluetooth.enable', SgdCategory.bluetooth),

  /// Whether the printer auto-reconnects to a previously paired host.
  /// Writable.
  bluetoothEnableReconnect('bluetooth.enable_reconnect', SgdCategory.bluetooth),

  /// Printer's advertised Bluetooth friendly name. Writable. Distinct
  /// from [deviceFriendlyName] on some firmwares.
  bluetoothFriendlyName('bluetooth.friendly_name', SgdCategory.bluetooth),

  /// BLE controller mode (`"central"`, `"peripheral"`, `"dual"`).
  /// Writable.
  bluetoothLeControllerMode(
    'bluetooth.le.controller_mode',
    SgdCategory.bluetooth,
  ),

  /// Minimum Bluetooth security level the printer will accept.
  /// Writable.
  bluetoothMinimumSecurityMode(
    'bluetooth.minimum_security_mode',
    SgdCategory.bluetooth,
  ),

  // ── Wi-Fi (WLAN) ────────────────────────────────────────────────

  /// WLAN allowed band (`"2.4"`, `"5"`, `"both"`). Writable.
  wlanAllowedBand('wlan.allowed_band', SgdCategory.wifi),

  /// ISO country code for WLAN regulatory domain. Writable.
  wlanCountryCode('wlan.country_code', SgdCategory.wifi),

  /// WLAN radio enable. Writable.
  wlanEnable('wlan.enable', SgdCategory.wifi),

  /// Currently configured WLAN SSID. Writable.
  wlanEssid('wlan.essid', SgdCategory.wifi),

  /// WLAN-subsystem IP address (primary network interface IP when
  /// associated). Read-only.
  wlanIpAddr('wlan.ip.addr', SgdCategory.wifi),

  /// DHCP client-identifier enable flag. Writable.
  wlanIpDhcpCidEnable('wlan.ip.dhcp.cid_enable', SgdCategory.wifi),

  /// DHCP client-identifier prefix. Writable.
  wlanIpDhcpCidPrefix('wlan.ip.dhcp.cid_prefix', SgdCategory.wifi),

  /// DHCP client-identifier suffix. Writable.
  wlanIpDhcpCidSuffix('wlan.ip.dhcp.cid_suffix', SgdCategory.wifi),

  /// DHCP client-identifier source type. Writable.
  wlanIpDhcpCidType('wlan.ip.dhcp.cid_type', SgdCategory.wifi),

  /// WLAN-subsystem gateway. Writable.
  wlanIpGateway('wlan.ip.gateway', SgdCategory.wifi),

  /// WLAN-subsystem netmask. Writable.
  wlanIpNetmask('wlan.ip.netmask', SgdCategory.wifi),

  /// WLAN IP protocol (`"dhcp"` / `"permanent"` / `"rarp"`). Writable.
  wlanIpProtocol('wlan.ip.protocol', SgdCategory.wifi),

  /// WLAN radio MAC address. Read-only.
  wlanMacAddr('wlan.mac_addr', SgdCategory.wifi),

  /// WLAN password / passphrase (WPA-PSK etc.). Write-only in practice.
  wlanPassword('wlan.password', SgdCategory.wifi),

  /// Permitted WLAN channel mask. Writable.
  wlanPermittedChannels('wlan.permitted_channels', SgdCategory.wifi),

  /// Power-save mode toggle. Writable.
  wlanPowerSave('wlan.power_save', SgdCategory.wifi),

  /// WLAN 802.1X private-key password. Writable.
  wlanPrivateKeyPassword('wlan.private_key_password', SgdCategory.wifi),

  /// WLAN security mode (`"open"`, `"wep"`, `"wpa"`, `"WPA-PSK"`, …).
  /// Writable.
  wlanSecurity('wlan.security', SgdCategory.wifi),

  /// Per-user channel list (advanced). Writable.
  wlanUserChannelList('wlan.user_channel_list', SgdCategory.wifi),

  /// WLAN 802.1X username. Writable.
  wlanUsername('wlan.username', SgdCategory.wifi),

  /// WPA pre-shared key. Writable. The primary Wi-Fi password field
  /// for WLAN provisioning over SGD.
  wlanWpaPsk('wlan.wpa.psk', SgdCategory.wifi),

  // ── Network / IP ────────────────────────────────────────────────

  /// Which interface the printer currently treats as active
  /// (`"wireless"`, `"internal wired"`, `"external wired"`, etc.).
  /// Zebra's own PrinterStatus layer reads this to decide the
  /// connection-type badge in their app.
  ipActiveNetwork('ip.active_network', SgdCategory.network),

  /// Primary IP address (whichever interface is active). Read-only.
  ipAddr('ip.addr', SgdCategory.network),

  /// Primary IP gateway.
  ipGateway('ip.gateway', SgdCategory.network),

  /// Primary IP netmask.
  ipNetmask('ip.netmask', SgdCategory.network),

  /// Raw UDP discovery-packet advertisement content.
  ipDiscoveryPacket('ip.discovery_packet', SgdCategory.network),

  /// FTP service enable. Writable. Disable for hardening.
  ipFtpEnable('ip.ftp.enable', SgdCategory.network),

  /// Admin-UI HTTP password. Sensitive — writable.
  ipHttpAdminPassword('ip.http.admin_password', SgdCategory.network),

  /// HTTPS service enable. Writable.
  ipHttpsEnable('ip.https.enable', SgdCategory.network),

  /// LPD print service enable. Writable.
  ipLpdEnable('ip.lpd.enable', SgdCategory.network),

  /// SNMP agent enable. Writable.
  ipSnmpEnable('ip.snmp.enable', SgdCategory.network),

  /// Raw TCP print socket (port 9100) service enable. Writable.
  /// Disable to force BLE/USB-only.
  ipTcpEnable('ip.tcp.enable', SgdCategory.network),

  /// Read-only IP of the currently-active interface. Mirrors
  /// [ipAddr] on most firmwares.
  interfaceNetworkActiveIpAddr(
    'interface.network.active.ip_addr',
    SgdCategory.network,
  ),

  // ── Odometer / Maintenance ──────────────────────────────────────

  /// Labels printed since the last head-clean reminder. Resettable
  /// by [deviceDiagnosticPrint]-class actions (firmware-specific).
  odometerHeadclean('odometer.headclean', SgdCategory.odometer),

  /// Labels printed since the printhead was installed new.
  odometerHeadnew('odometer.headnew', SgdCategory.odometer),

  /// Total dots-printed across the ribbon/media length — lifetime
  /// counter in dot-units.
  odometerLabelDotLength('odometer.label_dot_length', SgdCategory.odometer),

  /// How many times the media-cover latch has been opened.
  odometerLatchOpenCount('odometer.latch_open_count', SgdCategory.odometer),

  /// Count of detected media / black-mark notches.
  odometerMediaMarkerCount('odometer.media_marker_count', SgdCategory.odometer),

  /// RFID tags successfully written (resettable).
  odometerRfidValidResettable(
    'odometer.rfid.valid_resettable',
    SgdCategory.odometer,
  ),

  /// RFID tags voided (resettable).
  odometerRfidVoidResettable(
    'odometer.rfid.void_resettable',
    SgdCategory.odometer,
  ),

  /// Lifetime label count (non-resettable).
  odometerTotalLabelCount('odometer.total_label_count', SgdCategory.odometer),

  /// Lifetime print length in length-units (inches/mm per firmware).
  odometerTotalPrintLength('odometer.total_print_length', SgdCategory.odometer),

  // ── Actions (`do`-style) ────────────────────────────────────────

  /// Fires the "test label printed" action chain — used by Zebra's
  /// setup utility after a calibration run.
  actionTestLabelPrinted('action.test_label_printed', SgdCategory.action),

  /// Reports card-slot presence (for models with SD/SDIO slots).
  cardInserted('card.inserted', SgdCategory.action),

  /// Trigger a diagnostic-label print. Dumps current config + sample
  /// patterns. Useful maintenance entrypoint.
  deviceDiagnosticPrint('device.diagnostic_print', SgdCategory.action),

  /// Print the configuration label (the big "conf" printout Zebra
  /// ships with every printer).
  devicePrintOutReport('device.print_out_report', SgdCategory.action),

  /// Reboot the printer. Destructive to any in-flight print — guard
  /// with a confirmation dialog.
  deviceReset('device.reset', SgdCategory.action),

  /// Directory listing of the printer's internal filesystem.
  fileDir('file.dir', SgdCategory.action),

  /// Top-level drive listing (E:, R:, A:, B:).
  fileDriveListing('file.drive_listing', SgdCategory.action),

  /// File type classification query.
  fileType('file.type', SgdCategory.action),

  /// Run a media-calibration pass. Advances blank media to learn
  /// label length + inter-label gap.
  zplCalibrate('zpl.calibrate', SgdCategory.action),

  // ── Diagnostic ──────────────────────────────────────────────────

  /// Full printer status dump. Returns a **3-line response**; the
  /// trailing two lines will linger in the BLE notification buffer
  /// and corrupt the next SGD read. Always read last in a sweep and
  /// avoid calling on hot paths. Zebra's own `PrinterStatusZpl`
  /// reads this via `! U1 getvar "device.host_status"\r\n`.
  deviceHostStatus('device.host_status', SgdCategory.diagnostic),

  // ── Security / Admin ────────────────────────────────────────────

  /// Security mode (0–4 typically). Writable; enterprise-only.
  deviceAdvancedSecurityMode(
    'device.advanced_security_mode',
    SgdCategory.security,
  ),

  /// Firmware-update lockdown. Writable.
  deviceAllowFirmwareDownloads(
    'device.allow_firmware_downloads',
    SgdCategory.security,
  ),

  /// Protected-file-modification lockdown. Writable.
  deviceAllowProtectedFileModification(
    'device.allow_protected_file_modification',
    SgdCategory.security,
  ),

  /// FIPS-140-3 crypto-mode state. Writable only on firmware with
  /// the FIPS option loaded.
  deviceFipsEnabled('device.fips.enabled', SgdCategory.security),

  /// Prompt for network-reset confirmation on front panel. Writable.
  devicePromptedNetworkReset(
    'device.prompted_network_reset',
    SgdCategory.security,
  ),

  /// Printer protected-mode state.
  deviceProtectedMode('device.protected_mode', SgdCategory.security),

  /// Front-panel password value. Sensitive.
  displayPasswordCurrent('display.password.current', SgdCategory.security),

  // ── Other / Niche ───────────────────────────────────────────────

  /// Apple AirPrint / Bonjour protocol enable (model-dependent).
  /// Writable.
  aplEnable('apl.enable', SgdCategory.other),

  /// Staged enrollment / zero-touch-provisioning ZPL payload.
  enrollmentZpl('enrollment.zpl', SgdCategory.other),

  /// RFID encoder enable (only meaningful on RFID-capable models).
  /// Writable.
  rfidEnable('rfid.enable', SgdCategory.other),

  /// Zebra BASIC Interpreter enable. Writable.
  zbiEnable('zbi.enable', SgdCategory.other);

  const PrinterSgdKey(this.value, this.category);

  /// The raw SGD key string sent to the printer
  /// (`! U1 getvar "<value>"`, etc.).
  final String value;

  /// Logical grouping used for UI sections + safety policy.
  final SgdCategory category;
}
