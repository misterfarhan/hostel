/// Shared enums used across the domain. Each enum carries a human label so
/// the UI never has to switch on raw values.
library;

enum ListingPurpose {
  rent('Rent'),
  sale('Sale'),
  lease('Lease'),
  perSeat('Per seat');

  const ListingPurpose(this.label);
  final String label;
}

enum PricePeriod {
  perMonth('/ month'),
  perSeatMonth('/ seat / month'),
  perDay('/ day'),
  oneTime('');

  const PricePeriod(this.suffix);
  final String suffix;
}

enum ListingStatus {
  draft('Draft'),
  pendingReview('Pending review'),
  live('Live'),
  rejected('Rejected'),
  paused('Paused'),
  full('Full'),
  rented('Rented'),
  sold('Sold'),
  expired('Expired'),
  suspended('Suspended');

  const ListingStatus(this.label);
  final String label;

  bool get isVisibleToSeekers => this == ListingStatus.live;
}

enum OwnerStatus {
  notSubmitted('Not submitted'),
  pending('Pending'),
  underReview('Under review'),
  approved('Approved'),
  rejected('Rejected'),
  suspended('Suspended'),
  blocked('Blocked');

  const OwnerStatus(this.label);
  final String label;
}

enum DocumentStatus {
  missing('Not uploaded'),
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  expired('Expired');

  const DocumentStatus(this.label);
  final String label;
}

enum VisitStatus {
  requested('Requested'),
  accepted('Accepted'),
  rescheduled('Rescheduled'),
  declined('Declined'),
  expired('Expired'),
  onTheWay('On the way'),
  arrived('Arrived'),
  completed('Completed'),
  cancelled('Cancelled'),
  noShow('No show');

  const VisitStatus(this.label);
  final String label;

  bool get isOpen => const [VisitStatus.requested, VisitStatus.accepted, VisitStatus.rescheduled, VisitStatus.onTheWay, VisitStatus.arrived].contains(this);
}

enum JourneyStatus { onTheWay, arrived, completed, cancelled }

enum VisitOutcome {
  interested('Interested'),
  notInterested('Not interested'),
  needMoreTime('Need more time');

  const VisitOutcome(this.label);
  final String label;
}

enum GenderRule {
  any('Anyone'),
  male('Male only'),
  female('Female only'),
  family('Family only');

  const GenderRule(this.label);
  final String label;
}

enum NotificationCategory {
  properties('Properties'),
  visits('Visits'),
  messages('Messages'),
  payments('Payments'),
  promotions('Promotions'),
  security('Security'),
  support('Support'),
  system('System');

  const NotificationCategory(this.label);
  final String label;
}

enum TicketStatus {
  open('Open'),
  assigned('Assigned'),
  waitingForCustomer('Waiting for you'),
  inProgress('In progress'),
  resolved('Resolved'),
  closed('Closed');

  const TicketStatus(this.label);
  final String label;
}

enum ReportReason {
  wrongPrice('Wrong price'),
  wrongPhotos('Wrong photos'),
  notAvailable('Property not available'),
  wrongLocation('Wrong location'),
  fakeListing('Fake listing'),
  rudeBehaviour('Rude behaviour'),
  safetyIssue('Safety issue'),
  paymentIssue('Payment issue'),
  other('Other');

  const ReportReason(this.label);
  final String label;
}

enum SortOption {
  nearest('Nearest'),
  lowestPrice('Lowest price'),
  highestPrice('Highest price'),
  rating('Top rated'),
  newest('Newest'),
  seatsAvailable('Most seats');

  const SortOption(this.label);
  final String label;
}

enum AppMode { seeker, owner }
