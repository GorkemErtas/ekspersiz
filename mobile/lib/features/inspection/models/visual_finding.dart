/// Uncalibrated visual observations; historical detector data remains separate.
class VisualFinding {
  const VisualFinding({
    required this.damageType,
    required this.affectedPart,
    required this.severity,
    required this.description,
    required this.repairNotes,
    required this.replacementAssessment,
  });
  final String damageType;
  final String affectedPart;
  final String severity;
  final String description;
  final String repairNotes;
  final String replacementAssessment;

  factory VisualFinding.fromJson(Map<String, dynamic> json) => VisualFinding(
    damageType: json['damageType'] as String? ?? '',
    affectedPart: json['affectedPart'] as String? ?? 'UNKNOWN',
    severity: json['severity'] as String? ?? 'UNKNOWN',
    description: json['description'] as String? ?? '',
    repairNotes: json['repairNotes'] as String? ?? '',
    replacementAssessment:
        json['replacementAssessment'] as String? ?? 'UNDETERMINED',
  );
}
