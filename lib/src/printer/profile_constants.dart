/// Constants for printer profile creation and loading.
class ProfileConstants {
  ProfileConstants._();

  /// File extensions eligible for cloning in profiles.
  static const cloneableExtensions = {
    'ZPL',
    'GRF',
    'DAT',
    'BAS',
    'STO',
    'PNG',
    'LBL',
    'PCX',
    'BMP',
    'IMG',
    'WML',
    'HTM',
  };

  /// Common SGD settings captured during profile creation.
  static const cloneableSettings = [
    'media.type',
    'media.printmode',
    'ezpl.print_width',
    'ezpl.label_length',
    'ezpl.head_close_action',
    'ezpl.power_up_action',
    'ezpl.media_type',
    'media.tof',
    'media.darknessadjust',
    'device.friendly_name',
    'device.languages',
    'ip.addr',
    'ip.netmask',
    'ip.gateway',
    'ip.dhcp.enable',
    'wlan.essid',
    'wlan.security',
    'bluetooth.friendly_name',
    'bluetooth.enable',
    'weblink.ip.conn1.url',
    'weblink.ip.conn1.location',
    'zpl.label_length',
    'zpl.print_width',
    'device.printhead.resolution',
  ];
}
