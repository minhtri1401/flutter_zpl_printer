/// Describes a variable field (`^FN`) in a stored ZPL format.
///
/// Mirrors SDK's `FieldDescriptionData.java`.
class FieldDescription {
  /// 1-based field index from the `^FN` command.
  final int fieldNumber;

  /// Optional descriptive name (from `^FN1"Name"` syntax).
  final String? fieldName;

  const FieldDescription({required this.fieldNumber, this.fieldName});

  @override
  String toString() => 'FieldDescription(#$fieldNumber, name=$fieldName)';
}
