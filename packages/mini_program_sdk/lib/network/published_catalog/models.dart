part of '../published_mini_program_catalog_client.dart';

/// Lightweight catalog of published mini-programs exposed by backend discovery.
class PublishedMiniProgramCatalog {
  const PublishedMiniProgramCatalog({required this.entries, this.traceId});

  final List<PublishedMiniProgramSummary> entries;
  final String? traceId;
}

/// User-facing backend summary for one published mini-program.
class PublishedMiniProgramSummary {
  const PublishedMiniProgramSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.entry,
    required this.resolvedVersion,
    required this.requiredCapabilities,
    this.selectionMode,
    this.decisionReason,
    this.matchedRuleId,
  });

  factory PublishedMiniProgramSummary.fromJson(Map<String, dynamic> json) {
    final rawRequiredCapabilities =
        json['requiredCapabilities'] as List<dynamic>? ?? const [];

    return PublishedMiniProgramSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      entry: json['entry'] as String,
      resolvedVersion: json['resolvedVersion'] as String,
      requiredCapabilities: rawRequiredCapabilities
          .map((value) => CapabilityIds.normalizeObject(value))
          .toList(growable: false),
      selectionMode: json['selectionMode']?.toString(),
      decisionReason: json['decisionReason']?.toString(),
      matchedRuleId: json['matchedRuleId']?.toString(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String entry;
  final String resolvedVersion;
  final List<CapabilityId> requiredCapabilities;
  final String? selectionMode;
  final String? decisionReason;
  final String? matchedRuleId;
}
