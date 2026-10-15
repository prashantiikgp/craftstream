// GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND.
// ignore_for_file: type=lint

/// Field limits of LogDetail (models/), the same ones the API enforces.
abstract final class LogDetailLimits {
  static const keyMinLength = 1;
  static const keyMaxLength = 40;
  static const valueMaxLength = 300;
}

/// Field limits of LogEntry (models/), the same ones the API enforces.
abstract final class LogEntryLimits {
  static const eventMinLength = 1;
  static const eventMaxLength = 40;
  static const detailsMaxItems = 10;
}

/// Field limits of Order (models/), the same ones the API enforces.
abstract final class OrderLimits {
  static const buyerNameMinLength = 2;
  static const buyerNameMaxLength = 80;
  static const quantityMin = 1;
  static const quantityMax = 20;
}

/// Field limits of Product (models/), the same ones the API enforces.
abstract final class ProductLimits {
  static const titleMinLength = 3;
  static const titleMaxLength = 120;
  static const descriptionMaxLength = 5000;
  static const priceMin = 0.01;
  static const tagsMaxItems = 10;
  static const artisanNameMaxLength = 80;
}

/// Field limits of UploadPolicy (models/), the same ones the API enforces.
abstract final class UploadPolicyLimits {
  static const maxDurationSecondsMin = 1;
  static const chunkSizeBytesMin = 262144;
}

/// Field limits of UploadTicket (models/), the same ones the API enforces.
abstract final class UploadTicketLimits {
  static const chunkSizeBytesMin = 262144;
}
