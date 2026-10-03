import 'package:flutter/material.dart';
// Also brings in flutter_zpl_generator (ZplGenerator, ZplText, ...).
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import 'common.dart';
import 'test_image.dart';

const _sampleZpl = '''^XA
^CF0,40
^FO40,40^FDHello from Flutter^FS
^CF0,25
^FO40,95^FDflutter_zpl_printer^FS
^FO40,140^BY2^BCN,80,Y,N,N^FD123456789^FS
^XZ''';

/// A connected printer: status, identity, and a few common actions.
///
/// Commands run one at a time. Zebra printers answer on the same channel, so
/// overlapping requests (especially over Bluetooth) can mix up replies.
class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key, required this.printer, required this.title});

  final ZebraPrinter printer;
  final String title;

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final _zplController = TextEditingController(text: _sampleZpl);
  final _sgdController = TextEditingController(text: 'device.friendly_name');

  PrinterStatus? _status;
  Map<PrinterMetadataKey, String> _info = const {};
  String? _sgdResult;
  String? _busyLabel;

  ZebraPrinter get _printer => widget.printer;

  @override
  void initState() {
    super.initState();
    _run('Reading printer…', () async {
      await _loadStatus();
      await _loadInfo();
    });
  }

  /// Runs [action] unless another command is in flight, showing errors as snack bars.
  Future<void> _run(
    String label,
    Future<void> Function() action, {
    String? done,
  }) async {
    if (_busyLabel != null) return;
    setState(() => _busyLabel = label);
    try {
      await action();
      if (done != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  Future<void> _loadStatus() async {
    final status = await _printer.getStatus();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _loadInfo() async {
    // Keys a printer doesn't support are skipped, not thrown.
    final info = await _printer.getMetadata(
      keys: const [
        PrinterMetadataKey.deviceProductName,
        PrinterMetadataKey.deviceFriendlyName,
        PrinterMetadataKey.deviceUniqueId,
        PrinterMetadataKey.applName,
        PrinterMetadataKey.powerPercentFull,
        PrinterMetadataKey.ipAddr,
      ],
    );
    if (mounted) setState(() => _info = info);
  }

  Future<void> _print() => _run(
    'Printing…',
    () => _printer.printZpl(_zplController.text),
    done: 'Sent to printer',
  );

  /// Printable width in dots, as reported by the printer.
  Future<int> _printWidth() async {
    final raw = await _printer.getSetting(PrinterSgdKey.ezplPrintWidth.value);
    return int.tryParse(raw.trim()) ?? 384; // 2-inch, 203 dpi fallback
  }

  /// One call: `printImage` builds the label with flutter_zpl_generator
  /// (`~DG` download + `^XG` recall, uncompressed hex) and sends it.
  Future<void> _printImage() => _run('Printing image…', () async {
    await _printer.printImage(
      buildTestImagePng(),
      targetWidth: await _printWidth(),
    );
  }, done: 'Image sent (printImage)');

  /// Full control: build a label with flutter_zpl_generator (re-exported by
  /// this package) and send it with `printLabel`.
  Future<void> _printLabelWithImage() => _run('Printing label…', () async {
    final width = await _printWidth();
    await _printer.printLabel(
      ZplGenerator(
        config: ZplConfiguration(
          printWidth: width,
          printMode: ZplPrintMode.tearOff,
        ),
        autoLabelLengthFromFirstImage: true,
        commands: [
          ZplImageDownload(
            image: buildTestImagePng(),
            targetWidth: width,
            ditheringAlgorithm: ZplDitheringAlgorithm.threshold,
          ),
          const ZplImageRecall(),
        ],
      ),
    );
  }, done: 'Label sent (printLabel)');

  /// Low-level `GraphicsUtil.printImage`: inline `^GFA` graphic, not yet
  /// verified on a printer. [z64] switches to Z64 compression.
  Future<void> _printImageLowLevel({required bool z64}) =>
      _run('Printing image…', () async {
        await GraphicsUtil.printImage(
          _printer.connection,
          buildTestImagePng(),
          targetWidth: await _printWidth(),
          useCompression: z64,
        );
      }, done: z64 ? 'Image sent (^GF, Z64)' : 'Image sent (^GF, hex)');

  Future<void> _readSetting() async {
    final key = _sgdController.text.trim();
    if (key.isEmpty) return;
    await _run('Reading $key…', () async {
      final value = await _printer.getSetting(key);
      if (mounted) {
        setState(() => _sgdResult = value.isEmpty ? '(empty)' : value);
      }
    });
  }

  @override
  void dispose() {
    // Fire and forget: Bluetooth close waits a few seconds so the printer can
    // finish receiving data.
    _printer.disconnect().catchError((Object _) {});
    _zplController.dispose();
    _sgdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busyLabel != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(Icons.link_off),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(
            status: _status,
            onRefresh: busy
                ? null
                : () => _run('Refreshing status…', _loadStatus),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            info: _info,
            connection: _printer.connection.connectionDescription,
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Print ZPL',
            children: [
              TextField(
                controller: _zplController,
                minLines: 4,
                maxLines: 10,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : _print,
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Printer actions',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _run(
                            'Printing configuration label…',
                            _printer.printConfigurationLabel,
                            done: 'Configuration label sent',
                          ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Configuration label'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _run(
                            'Calibrating…',
                            _printer.calibrate,
                            done: 'Calibration started',
                          ),
                    icon: const Icon(Icons.straighten),
                    label: const Text('Calibrate media'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Print image',
            children: [
              Text(
                'printImage and printLabel use flutter_zpl_generator, the path tested on '
                'hardware. The advanced GraphicsUtil (^GF) options have not been verified '
                'on a printer yet: compare their output with the first two.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : _printImage,
                    icon: const Icon(Icons.image),
                    label: const Text('printImage'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : _printLabelWithImage,
                    icon: const Icon(Icons.label_outline),
                    label: const Text('printLabel (ZplGenerator)'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Advanced: GraphicsUtil.printImage (^GF)',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _printImageLowLevel(z64: false),
                    child: const Text('^GF hex'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _printImageLowLevel(z64: true),
                    child: const Text('^GF Z64'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Read a setting (SGD)',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sgdController,
                      onSubmitted: (_) => _readSetting(),
                      decoration: const InputDecoration(
                        labelText: 'Setting name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: busy ? null : _readSetting,
                    child: const Text('Get'),
                  ),
                ],
              ),
              if (_sgdResult != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  _sgdResult!,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.onRefresh});

  final PrinterStatus? status;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      title: 'Status',
      trailing: IconButton(
        tooltip: 'Refresh status',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
      children: [
        if (s == null)
          const Text('Not read yet')
        else ...[
          Row(
            children: [
              Icon(
                s.isReadyToPrint ? Icons.check_circle : Icons.error,
                color: s.isReadyToPrint ? Colors.green : scheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                s.isReadyToPrint ? 'Ready to print' : 'Not ready',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _flag('Head open', s.isHeadOpen),
              _flag('Paper out', s.isPaperOut),
              _flag('Ribbon out', s.isRibbonOut),
              _flag('Paused', s.isPaused),
              _flag('Head too hot', s.isHeadTooHot),
              _flag('Buffer full', s.isReceiveBufferFull),
            ],
          ),
        ],
      ],
    );
  }

  Widget _flag(String label, bool on) => Chip(
    avatar: Icon(on ? Icons.warning_amber : Icons.check, size: 18),
    label: Text(label),
    backgroundColor: on ? Colors.orange.withValues(alpha: 0.2) : null,
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.info, required this.connection});

  final Map<PrinterMetadataKey, String> info;
  final String connection;

  static const _labels = {
    PrinterMetadataKey.deviceProductName: 'Model',
    PrinterMetadataKey.deviceFriendlyName: 'Name',
    PrinterMetadataKey.deviceUniqueId: 'Serial',
    PrinterMetadataKey.applName: 'Firmware',
    PrinterMetadataKey.powerPercentFull: 'Battery %',
    PrinterMetadataKey.ipAddr: 'IP address',
  };

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Connection', connection),
      for (final e in _labels.entries)
        // Printers answer "?" for settings they don't have (e.g. battery on desktops).
        if ((info[e.key] ?? '').isNotEmpty && info[e.key] != '?')
          MapEntry(e.value, info[e.key]!),
    ];
    return _Section(
      title: 'Printer info',
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row.key,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
                Expanded(child: SelectableText(row.value)),
              ],
            ),
          ),
      ],
    );
  }
}
