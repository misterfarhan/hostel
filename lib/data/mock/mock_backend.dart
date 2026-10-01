import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../search_matcher.dart';
import 'seed_data.dart';

/// Holds a value and replays it to every new listener, like a BehaviorSubject.
class _Live<T> {
  _Live(this._value);
  T _value;
  final _controller = StreamController<T>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    _controller.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }
}

/// In-memory implementation of every repository, seeded with demo data.
///
/// It also simulates the "other side" of the marketplace so the app feels
/// alive during demos: owners reply to chats, accept visit requests, the
/// admin approves documents and listings after a short delay, and so on.
/// Replace with real implementations when the backend is ready.
class MockBackend implements AuthRepository, PropertyRepository, ActivityRepository, ChatRepository, SupportRepository {
  MockBackend(this.config, this._prefs) {
    final seed = SeedData(config);
    for (final u in [...seed.owners, ...seed.seekers]) {
      _users[u.id] = u;
    }
    _properties.value = {for (final p in seed.properties) p.id: p};
    _reviews.value = seed.reviews;
    _restoreSession();
  }

  /// Every OTP is accepted if it equals this code (demo only).
  static const demoOtp = '123456';

  final AppConfig config;
  final SharedPreferences _prefs;
  final _rnd = Random();
  var _idCounter = 0;

  final _users = <String, AppUser>{};
  final _currentUser = _Live<AppUser?>(null);
  final _properties = _Live<Map<String, Property>>({});
  final _reviews = _Live<List<Review>>([]);
  final _favourites = _Live<Map<String, Set<String>>>({});
  final _savedSearches = _Live<List<SavedSearch>>([]);
  final _visits = _Live<List<VisitRequest>>([]);
  final _inquiries = _Live<List<Inquiry>>([]);
  final _conversations = _Live<Map<String, Conversation>>({});
  final _messages = _Live<Map<String, List<ChatMessage>>>({});
  final _notifications = _Live<List<AppNotification>>([]);
  final _tickets = _Live<List<SupportTicket>>([]);
  final _reports = <ListingReport>[];
  final _journeys = <String, VisitJourney>{};
  final _otpRequests = <String, List<DateTime>>{};

  String _id(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
  Future<void> _latency([int ms = 350]) => Future.delayed(Duration(milliseconds: ms));

  // ---------------------------------------------------------------------------
  // Session persistence (demo): remember who is logged in and their favourites.
  // ---------------------------------------------------------------------------

  void _restoreSession() {
    final phone = _prefs.getString('session.phone');
    if (phone == null) return;
    final user = AppUser(
      id: _userIdFor(phone),
      phone: phone,
      name: _prefs.getString('session.name') ?? '',
      countryId: _prefs.getString('session.country'),
      cityId: _prefs.getString('session.city'),
      email: _prefs.getString('session.email'),
      ownerStatus: OwnerStatus.values.byName(_prefs.getString('session.ownerStatus') ?? 'notSubmitted'),
      documents: _defaultDocuments(),
      referralCode: _referralFor(phone),
      joinedAt: DateTime.now(),
    );
    _users[user.id] = user;
    _currentUser.value = user;
    final favs = _prefs.getStringList('session.favourites') ?? const [];
    _favourites.value = {user.id: favs.toSet()};
    _welcome(user);
  }

  Future<void> _persistSession(AppUser user) async {
    await _prefs.setString('session.phone', user.phone);
    await _prefs.setString('session.name', user.name);
    if (user.countryId != null) await _prefs.setString('session.country', user.countryId!);
    if (user.cityId != null) await _prefs.setString('session.city', user.cityId!);
    if (user.email != null) await _prefs.setString('session.email', user.email!);
    await _prefs.setString('session.ownerStatus', user.ownerStatus.name);
  }

  String _userIdFor(String phone) => 'u_${phone.replaceAll(RegExp(r'\D'), '')}';
  String _referralFor(String phone) => 'SF${phone.replaceAll(RegExp(r'\D'), '').substring(max(0, phone.length - 7))}';

  List<OwnerDocument> _defaultDocuments() => const [
    OwnerDocument(kind: 'photo', label: 'Profile photo', status: DocumentStatus.missing),
    OwnerDocument(kind: 'id', label: 'National ID / Passport', status: DocumentStatus.missing),
    OwnerDocument(kind: 'ownership', label: 'Proof of ownership or authority letter', status: DocumentStatus.missing),
    OwnerDocument(kind: 'utility', label: 'Utility bill', status: DocumentStatus.missing, required: false),
  ];

  void _welcome(AppUser user) {
    if (_notifications.value.any((n) => n.userId == user.id)) return;
    final now = DateTime.now();
    _notifications.value = [
      AppNotification(
        id: _id('n'),
        userId: user.id,
        category: NotificationCategory.system,
        title: 'Welcome to StayFinder',
        body: 'Find hostels, flats, shops and land around you. Set a radius and explore the map.',
        createdAt: now,
      ),
      AppNotification(
        id: _id('n'),
        userId: user.id,
        category: NotificationCategory.security,
        title: 'Stay safe',
        body: 'Never pay advance money before visiting a property, and never outside the app.',
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
      ..._notifications.value,
    ];
  }

  void _notify(String userId, NotificationCategory category, String title, String body, {String? link}) {
    _notifications.value = [
      AppNotification(id: _id('n'), userId: userId, category: category, title: title, body: body, createdAt: DateTime.now(), deepLink: link),
      ..._notifications.value,
    ];
  }

  // ---------------------------------------------------------------------------
  // AuthRepository
  // ---------------------------------------------------------------------------

  @override
  AppUser? get currentUser => _currentUser.value;

  @override
  Stream<AppUser?> watchCurrentUser() => _currentUser.stream;

  @override
  Future<void> requestOtp(String phone) async {
    await _latency(700);
    final now = DateTime.now();
    final recent = (_otpRequests[phone] ?? []).where((t) => now.difference(t).inMinutes < 10).toList();
    if (recent.length >= 5) {
      throw const AppException('Too many OTP requests. Please try again in 10 minutes.');
    }
    _otpRequests[phone] = [...recent, now];
  }

  @override
  Future<AppUser> verifyOtp(String phone, String code) async {
    await _latency(700);
    if (code != demoOtp) throw const AppException('Incorrect code. Please check the SMS and try again.');
    final id = _userIdFor(phone);
    final user =
        _users[id] ?? AppUser(id: id, phone: phone, name: '', documents: _defaultDocuments(), referralCode: _referralFor(phone), joinedAt: DateTime.now());
    _users[id] = user;
    _currentUser.value = user;
    await _persistSession(user);
    _welcome(user);
    return user;
  }

  @override
  Future<AppUser> updateProfile(AppUser user) async {
    await _latency();
    _users[user.id] = user;
    _currentUser.value = user;
    await _persistSession(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await _latency(200);
    await _prefs.clear();
    _currentUser.value = null;
  }

  @override
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;
    final active = _visits.value.where((v) => v.seekerId == user.id && v.status == VisitStatus.onTheWay);
    if (active.isNotEmpty) throw const AppException('Finish or cancel your active visit before deleting your account.');
    _properties.value = {for (final p in _properties.value.values) p.id: p.ownerId == user.id ? p.copyWith(status: ListingStatus.suspended) : p};
    _users.remove(user.id);
    await logout();
  }

  @override
  Future<AppUser?> userById(String id) async => _users[id];

  @override
  Future<AppUser> uploadOwnerDocument(String kind, String filePath) async {
    await _latency(600);
    final user = currentUser!;
    final docs = [for (final d in user.documents) d.kind == kind ? d.copyWith(status: DocumentStatus.pending, filePath: filePath) : d];
    return updateProfile(user.copyWith(documents: docs, photoUrl: kind == 'photo' ? filePath : null));
  }

  @override
  Future<AppUser> submitOwnerVerification() async {
    final user = currentUser!;
    final missing = user.documents.where((d) => d.required && d.status == DocumentStatus.missing);
    if (missing.isNotEmpty) throw AppException('Please upload: ${missing.map((d) => d.label).join(', ')}');
    final updated = await updateProfile(user.copyWith(ownerStatus: OwnerStatus.underReview));
    // Simulated admin review.
    Timer(const Duration(seconds: 6), () async {
      final u = _users[user.id];
      if (u == null) return;
      await updateProfile(
        u.copyWith(
          ownerStatus: OwnerStatus.approved,
          badges: [OwnerBadge.verifiedOwner],
          documents: [for (final d in u.documents) d.status == DocumentStatus.pending ? d.copyWith(status: DocumentStatus.approved) : d],
        ),
      );
      _notify(u.id, NotificationCategory.security, 'You are verified!', 'Your owner account is approved. You can now publish listings.', link: '/owner');
    });
    return updated;
  }

  // ---------------------------------------------------------------------------
  // PropertyRepository
  // ---------------------------------------------------------------------------

  bool _visibleToSeekers(Property p) => p.status == ListingStatus.live || (config.showFullListingsWithBadge && p.status == ListingStatus.full);

  @override
  Stream<List<Property>> watchLive() => _properties.stream.map((m) => m.values.where(_visibleToSeekers).toList(growable: false));

  @override
  Future<List<Property>> search(SearchQuery q) async {
    await _latency(450);
    return _properties.value.values.where((p) => matches(p, q)).toList();
  }

  bool matches(Property p, SearchQuery q) => SearchMatcher.matches(p, q, showFull: config.showFullListingsWithBadge);

  @override
  Stream<Property?> watchProperty(String id) => _properties.stream.map((m) => m[id]);

  @override
  Stream<List<Property>> watchOwnerProperties(String ownerId) =>
      _properties.stream.map((m) => m.values.where((p) => p.ownerId == ownerId).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  void _put(Property p) => _properties.value = {..._properties.value, p.id: p};

  @override
  Future<Property> saveProperty(Property property) async {
    await _latency(500);
    final saved = property.id.isEmpty
        ? Property.fromJson({
            ...property.toJson(),
            'id': _id('p'),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
        : property.copyWith(updatedAt: DateTime.now());
    _put(saved);
    return saved;
  }

  @override
  Future<void> submitForReview(String id) async {
    final user = currentUser;
    final p = _properties.value[id];
    if (p == null || user == null) return;
    if (!user.canPublish) throw const AppException('Your owner account must be approved before you can publish.');
    final liveCount = _properties.value.values.where((e) => e.ownerId == user.id && e.status == ListingStatus.live).length;
    if (liveCount >= config.freeListingLimit) {
      throw AppException('Free plan allows ${config.freeListingLimit} live listings. Upgrade your plan to publish more.');
    }
    final type = config.type(p.typeId);
    if (p.photos.length < type.minPhotos) throw AppException('Add at least ${type.minPhotos} photos.');
    await _latency();
    _put(p.copyWith(status: ListingStatus.pendingReview));
    // Simulated moderation: approve after a short review.
    Timer(const Duration(seconds: 5), () {
      final current = _properties.value[id];
      if (current == null || current.status != ListingStatus.pendingReview) return;
      final now = DateTime.now();
      _put(current.copyWith(status: ListingStatus.live, expiresAt: now.add(const Duration(days: 90)), lastConfirmedAt: now));
      _notify(current.ownerId, NotificationCategory.properties, 'Listing approved', '"${current.title}" is now live on the map.', link: '/manage/$id');
      _simulateSeekerInterest(current);
    });
  }

  /// After a listing goes live, a demo seeker sends an inquiry and a visit
  /// request so the owner can try the full flow.
  void _simulateSeekerInterest(Property p) {
    Timer(const Duration(seconds: 12), () {
      final seeker = _users['seeker_0'];
      if (seeker == null || _properties.value[p.id]?.status != ListingStatus.live) return;
      sendInquiry(propertyId: p.id, seeker: seeker, message: 'Hi, is this still available? I would like to visit this week.');
      requestVisit(propertyId: p.id, seekerId: seeker.id, time: DateTime.now().add(const Duration(days: 1, hours: 2)), message: 'Can I come tomorrow evening?');
    });
  }

  @override
  Future<void> setStatus(String id, ListingStatus status) async {
    await _latency();
    final p = _properties.value[id];
    if (p == null) return;
    if (status == ListingStatus.live && p.status == ListingStatus.expired) {
      _put(p.copyWith(status: ListingStatus.live, expiresAt: DateTime.now().add(const Duration(days: 90))));
      return;
    }
    _put(p.copyWith(status: status));
  }

  @override
  Future<void> updateAvailability(String id, int availableUnits) async {
    final p = _properties.value[id];
    if (p == null) return;
    final units = availableUnits.clamp(0, max(p.totalUnits, availableUnits)).toInt();
    var status = p.status;
    if (units == 0 && status == ListingStatus.live) status = ListingStatus.full;
    if (units > 0 && status == ListingStatus.full) status = ListingStatus.live;
    _put(p.copyWith(availableUnits: units, status: status));
  }

  @override
  Future<void> updatePrice(String id, double price) async {
    await _latency();
    final p = _properties.value[id];
    if (p != null) _put(p.copyWith(price: price));
  }

  @override
  Future<void> confirmStillAvailable(String id) async {
    await _latency();
    final p = _properties.value[id];
    if (p != null) _put(p.copyWith(lastConfirmedAt: DateTime.now()));
  }

  @override
  Future<void> deleteProperty(String id) async {
    await _latency();
    _properties.value = {..._properties.value}..remove(id);
  }

  @override
  Future<void> recordView(String id) async {
    final p = _properties.value[id];
    if (p != null) _properties.value[id] = p.copyWith(viewsCount: p.viewsCount + 1, updatedAt: p.updatedAt);
  }

  @override
  Stream<List<Review>> watchReviews(String propertyId) =>
      _reviews.stream.map((all) => all.where((r) => r.propertyId == propertyId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  @override
  Future<void> addReview(Review review, {required String visitRequestId}) async {
    await _latency();
    final visit = _visits.value.where((v) => v.id == visitRequestId).firstOrNull;
    if (visit == null || visit.status != VisitStatus.completed) {
      throw const AppException('You can review a property only after a confirmed visit.');
    }
    if (visit.reviewed) throw const AppException('You have already reviewed this visit.');
    final p = _properties.value[review.propertyId];
    if (p != null && p.ownerId == review.authorId) throw const AppException('You cannot review your own property.');
    _reviews.value = [review, ..._reviews.value];
    _visits.value = [for (final v in _visits.value) v.id == visitRequestId ? v.copyWith(reviewed: true) : v];
    if (p != null) {
      final total = p.averageRating * p.reviewCount + review.overall;
      _put(p.copyWith(reviewCount: p.reviewCount + 1, averageRating: double.parse((total / (p.reviewCount + 1)).toStringAsFixed(1))));
      _notify(p.ownerId, NotificationCategory.properties, 'New review', '${review.authorName} rated "${p.title}" ${review.overall.toStringAsFixed(0)}★');
    }
  }

  @override
  Future<void> report(ListingReport report) async {
    await _latency();
    _reports.add(report);
    _notify(
      report.reporterId,
      NotificationCategory.support,
      'Report received',
      'Thanks for helping keep StayFinder safe. Our team will review your report (${report.reason.label}) within 24 hours.',
    );
  }

  @override
  Future<double?> averagePrice({required String typeId, required String cityId, required String area}) async {
    await _latency(200);
    final similar = _properties.value.values
        .where((p) => p.typeId == typeId && p.cityId == cityId && p.status == ListingStatus.live && p.pricePeriod != PricePeriod.oneTime)
        .toList();
    if (similar.isEmpty) return null;
    final inArea = similar.where((p) => p.area == area).toList();
    final list = inArea.length >= 3 ? inArea : similar;
    return list.map((p) => p.price).reduce((a, b) => a + b) / list.length;
  }

  // ---------------------------------------------------------------------------
  // ActivityRepository
  // ---------------------------------------------------------------------------

  @override
  Stream<Set<String>> watchFavourites(String userId) => _favourites.stream.map((m) => m[userId] ?? const {});

  @override
  Future<void> toggleFavourite(String userId, String propertyId) async {
    final current = <String>{...?_favourites.value[userId]};
    final adding = !current.contains(propertyId);
    adding ? current.add(propertyId) : current.remove(propertyId);
    _favourites.value = {..._favourites.value, userId: current};
    final p = _properties.value[propertyId];
    if (p != null) {
      _properties.value[propertyId] = p.copyWith(favouritesCount: max(0, p.favouritesCount + (adding ? 1 : -1)), updatedAt: p.updatedAt);
    }
    if (userId == currentUser?.id) await _prefs.setStringList('session.favourites', current.toList());
  }

  @override
  Stream<List<SavedSearch>> watchSavedSearches(String userId) => _savedSearches.stream;

  @override
  Future<void> saveSearch(String userId, String name, SearchQuery query) async {
    await _latency();
    _savedSearches.value = [SavedSearch(id: _id('ss'), name: name, query: query, createdAt: DateTime.now()), ..._savedSearches.value];
  }

  @override
  Future<void> toggleSearchAlerts(String id, bool enabled) async {
    _savedSearches.value = [for (final s in _savedSearches.value) s.id == id ? s.copyWith(alertsEnabled: enabled) : s];
  }

  @override
  Future<void> deleteSavedSearch(String id) async {
    _savedSearches.value = _savedSearches.value.where((s) => s.id != id).toList();
  }

  List<VisitRequest> _sortedVisits(Iterable<VisitRequest> v) => v.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<VisitRequest>> watchSeekerVisits(String seekerId) => _visits.stream.map((all) => _sortedVisits(all.where((v) => v.seekerId == seekerId)));

  @override
  Stream<List<VisitRequest>> watchOwnerVisits(String ownerId) => _visits.stream.map((all) => _sortedVisits(all.where((v) => v.ownerId == ownerId)));

  void _updateVisit(String id, VisitRequest Function(VisitRequest) change) {
    _visits.value = [for (final v in _visits.value) v.id == id ? change(v) : v];
  }

  @override
  Future<VisitRequest> requestVisit({required String propertyId, required String seekerId, required DateTime time, String message = ''}) async {
    await _latency();
    final p = _properties.value[propertyId]!;
    final existing = _visits.value.where((v) => v.propertyId == propertyId && v.seekerId == seekerId && v.status.isOpen);
    if (existing.isNotEmpty) throw const AppException('You already have an open visit request for this property.');
    final visit = VisitRequest(
      id: _id('v'),
      propertyId: propertyId,
      seekerId: seekerId,
      ownerId: p.ownerId,
      preferredTime: time,
      status: VisitStatus.requested,
      createdAt: DateTime.now(),
      message: message,
      visitCode: (1000 + _rnd.nextInt(9000)).toString(),
    );
    _visits.value = [visit, ..._visits.value];
    final seeker = _users[seekerId];
    _notify(p.ownerId, NotificationCategory.visits, 'New visit request', '${seeker?.name ?? 'A seeker'} wants to visit "${p.title}".', link: '/owner/requests');

    // Seeded owners respond automatically.
    if (p.ownerId.startsWith('owner_')) {
      Timer(const Duration(seconds: 4), () {
        final accept = _rnd.nextInt(5) != 0;
        _updateVisit(
          visit.id,
          (v) => v.copyWith(status: accept ? VisitStatus.accepted : VisitStatus.rescheduled, proposedTime: accept ? null : time.add(const Duration(hours: 3))),
        );
        _notify(
          seekerId,
          NotificationCategory.visits,
          accept ? 'Visit accepted' : 'Owner suggested another time',
          accept
              ? 'Your visit to "${p.title}" on ${_shortDate(time)} is confirmed.'
              : 'The owner of "${p.title}" suggested ${_shortDate(time.add(const Duration(hours: 3)))}.',
          link: '/visits',
        );
      });
    }
    return visit;
  }

  String _shortDate(DateTime d) =>
      '${d.day}/${d.month} at ${d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour)}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';

  @override
  Future<void> respondToVisit(String id, VisitStatus status, {DateTime? proposedTime}) async {
    await _latency();
    final visit = _visits.value.firstWhere((v) => v.id == id);
    _updateVisit(id, (v) => v.copyWith(status: status, proposedTime: proposedTime));
    final p = _properties.value[visit.propertyId];
    final title = p?.title ?? 'the property';
    final (who, msg) = switch (status) {
      VisitStatus.accepted => (visit.seekerId, 'Your visit to "$title" was accepted.'),
      VisitStatus.declined => (visit.seekerId, 'Your visit request for "$title" was declined.'),
      VisitStatus.rescheduled => (visit.seekerId, 'The owner suggested a new time for "$title".'),
      VisitStatus.cancelled => (visit.ownerId, 'A visit to "$title" was cancelled.'),
      VisitStatus.onTheWay => (visit.ownerId, 'A visitor is on the way to "$title".'),
      VisitStatus.arrived => (visit.ownerId, 'Your visitor has arrived at "$title".'),
      VisitStatus.noShow => (visit.seekerId, 'You were marked as no-show for "$title".'),
      _ => ('', ''),
    };
    if (who.isNotEmpty) _notify(who, NotificationCategory.visits, 'Visit ${status.label.toLowerCase()}', msg, link: '/visits');

    // Demo seeker accepts an owner's reschedule automatically.
    if (status == VisitStatus.rescheduled && visit.seekerId.startsWith('seeker_')) {
      Timer(const Duration(seconds: 4), () => _updateVisit(id, (v) => v.copyWith(status: VisitStatus.accepted)));
    }
  }

  @override
  Future<void> confirmVisitCode(String id, String code) async {
    await _latency();
    final visit = _visits.value.firstWhere((v) => v.id == id);
    if (visit.visitCode != code.trim()) throw const AppException('That code does not match. Ask the owner to show the code again.');
    _updateVisit(id, (v) => v.copyWith(status: VisitStatus.completed));
    final p = _properties.value[visit.propertyId];
    if (p != null) _properties.value[p.id] = p.copyWith(visitsCount: p.visitsCount + 1, updatedAt: p.updatedAt);
  }

  @override
  Future<void> setVisitOutcome(String id, VisitOutcome outcome) async {
    _updateVisit(id, (v) => v.copyWith(outcome: outcome));
  }

  @override
  Stream<List<Inquiry>> watchOwnerInquiries(String ownerId) => _inquiries.stream.map((all) {
    final mine = all.where((i) => _properties.value[i.propertyId]?.ownerId == ownerId).toList();
    return mine..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<void> sendInquiry({required String propertyId, required AppUser seeker, required String message, DateTime? preferredVisit}) async {
    await _latency();
    final p = _properties.value[propertyId];
    if (p == null) return;
    _inquiries.value = [
      Inquiry(
        id: _id('i'),
        propertyId: propertyId,
        seekerId: seeker.id,
        seekerName: seeker.name,
        message: message,
        createdAt: DateTime.now(),
        preferredVisit: preferredVisit,
      ),
      ..._inquiries.value,
    ];
    _put(p.copyWith(inquiriesCount: p.inquiriesCount + 1, updatedAt: p.updatedAt));
    _notify(p.ownerId, NotificationCategory.properties, 'New inquiry', '${seeker.name}: "$message"', link: '/owner/requests');
    // Inquiries also open a chat thread.
    final convo = await openConversation(propertyId: propertyId, seekerId: seeker.id, ownerId: p.ownerId);
    await sendMessage(ChatMessage(id: _id('m'), conversationId: convo.id, senderId: seeker.id, kind: MessageKind.text, sentAt: DateTime.now(), text: message));
  }

  @override
  Future<void> markInquiryHandled(String id) async {
    _inquiries.value = [
      for (final i in _inquiries.value)
        i.id == id
            ? Inquiry(
                id: i.id,
                propertyId: i.propertyId,
                seekerId: i.seekerId,
                seekerName: i.seekerName,
                message: i.message,
                createdAt: i.createdAt,
                preferredVisit: i.preferredVisit,
                handled: true,
              )
            : i,
    ];
  }

  @override
  Future<VisitJourney> startJourney({required String seekerId, required String propertyId, String? visitRequestId, required bool shareWithOwner}) async {
    await _latency(250);
    final j = VisitJourney(
      id: _id('j'),
      seekerId: seekerId,
      propertyId: propertyId,
      visitRequestId: visitRequestId,
      status: JourneyStatus.onTheWay,
      shareWithOwner: shareWithOwner,
      startTime: DateTime.now(),
      shareLink: 'https://stayfinder.app/trip/${_rnd.nextInt(1 << 31).toRadixString(36)}',
    );
    _journeys[j.id] = j;
    if (visitRequestId != null) _updateVisit(visitRequestId, (v) => v.copyWith(status: VisitStatus.onTheWay));
    if (shareWithOwner) {
      final p = _properties.value[propertyId];
      if (p != null) _notify(p.ownerId, NotificationCategory.visits, 'Visitor on the way', 'Someone is heading to "${p.title}".');
    }
    return j;
  }

  @override
  Future<void> updateJourney(VisitJourney journey) async {
    _journeys[journey.id] = journey;
    final visitId = journey.visitRequestId;
    if (visitId == null) return;
    final status = switch (journey.status) {
      JourneyStatus.arrived => VisitStatus.arrived,
      JourneyStatus.cancelled => VisitStatus.accepted,
      _ => null,
    };
    if (status != null) _updateVisit(visitId, (v) => v.copyWith(status: status));
  }

  // ---------------------------------------------------------------------------
  // ChatRepository
  // ---------------------------------------------------------------------------

  static const _ownerReplies = [
    'Yes, it is available. When would you like to visit?',
    'Thank you for your interest! You can visit any day between 11 AM and 7 PM.',
    'Sure, I can share more photos. The price is slightly negotiable.',
    'Please send a visit request from the app and I will confirm it.',
  ];

  @override
  Stream<List<Conversation>> watchConversations(String userId) => _conversations.stream.map((m) {
    final list = m.values.where((c) => c.seekerId == userId || c.ownerId == userId).toList();
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  });

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) => _messages.stream.map((m) => m[conversationId] ?? const []);

  @override
  Future<Conversation> openConversation({required String propertyId, required String seekerId, required String ownerId}) async {
    final existing = _conversations.value.values.where((c) => c.propertyId == propertyId && c.seekerId == seekerId && c.ownerId == ownerId).firstOrNull;
    if (existing != null) return existing;
    final c = Conversation(id: _id('c'), propertyId: propertyId, seekerId: seekerId, ownerId: ownerId, updatedAt: DateTime.now());
    _conversations.value = {..._conversations.value, c.id: c};
    return c;
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    final convo = _conversations.value[message.conversationId];
    if (convo == null) return;
    if (convo.blockedBy != null) throw const AppException('This conversation is blocked.');
    final list = [...?_messages.value[convo.id], message];
    _messages.value = {..._messages.value, convo.id: list};
    final recipient = convo.otherParty(message.senderId);
    _conversations.value = {
      ..._conversations.value,
      convo.id: convo.copyWith(
        updatedAt: message.sentAt,
        lastMessage: message,
        unreadFor: {...convo.unreadFor, recipient: (convo.unreadFor[recipient] ?? 0) + 1},
      ),
    };

    // Seeded owners reply after a short pause.
    if (recipient.startsWith('owner_') && message.senderId == convo.seekerId) {
      final alreadyReplied = list.where((m) => m.senderId == recipient).length;
      if (alreadyReplied < 3) {
        Timer(Duration(seconds: 2 + _rnd.nextInt(3)), () {
          sendMessage(
            ChatMessage(
              id: _id('m'),
              conversationId: convo.id,
              senderId: recipient,
              kind: MessageKind.text,
              sentAt: DateTime.now(),
              text: _ownerReplies[alreadyReplied % _ownerReplies.length],
            ),
          );
          final owner = _users[recipient];
          _notify(
            convo.seekerId,
            NotificationCategory.messages,
            owner?.name ?? 'Owner replied',
            _ownerReplies[alreadyReplied % _ownerReplies.length],
            link: '/chat/${convo.id}',
          );
        });
      }
    }
  }

  @override
  Future<void> markRead(String conversationId, String userId) async {
    final convo = _conversations.value[conversationId];
    if (convo == null || (convo.unreadFor[userId] ?? 0) == 0) return;
    _conversations.value = {
      ..._conversations.value,
      conversationId: convo.copyWith(unreadFor: {...convo.unreadFor, userId: 0}),
    };
  }

  @override
  Future<void> block(String conversationId, String userId) async {
    final convo = _conversations.value[conversationId];
    if (convo == null) return;
    _conversations.value = {..._conversations.value, conversationId: convo.copyWith(blockedBy: userId)};
  }

  // ---------------------------------------------------------------------------
  // Notifications (exposed through [MockNotificationRepository] because both
  // chat and notifications define `markRead`).
  // ---------------------------------------------------------------------------

  Stream<List<AppNotification>> watchNotifications(String userId) => _notifications.stream.map((all) => all.where((n) => n.userId == userId).toList());

  Future<void> markNotificationRead(String id) async {
    _notifications.value = [for (final n in _notifications.value) n.id == id ? n.markRead() : n];
  }

  Future<void> markAllRead(String userId) async {
    _notifications.value = [for (final n in _notifications.value) n.userId == userId ? n.markRead() : n];
  }

  // ---------------------------------------------------------------------------
  // SupportRepository
  // ---------------------------------------------------------------------------

  @override
  List<FaqItem> get faqs => const [
    FaqItem(
      'How does the radius search work?',
      'Pick a property type, city and radius. We draw a circle around your search centre and show every live listing inside it as a pin and in the list.',
    ),
    FaqItem('Is my phone number shared with owners?', 'No. Calls and chats are masked. Your real number is shared only if both of you agree.'),
    FaqItem('Should I pay an advance before visiting?', 'Never. Always visit the property first and never pay outside the StayFinder protected flow.'),
    FaqItem(
      'What does the Verified badge mean?',
      'Verified Owner means we checked the owner\'s ID. Verified Listing means we checked ownership documents or visited the site.',
    ),
    FaqItem('How do I list my property?', 'Switch to Owner Mode from your profile, upload your ID and ownership proof, then tap Add Property.'),
    FaqItem(
      'What is the visit code?',
      'When you arrive, the owner shows a 4-digit code. Entering it confirms the visit really happened, so only genuine visitors can leave reviews.',
    ),
    FaqItem('How do I report a fake listing?', 'Open the listing, tap the menu and choose Report listing. Our team reviews every report within 24 hours.'),
  ];

  @override
  Stream<List<SupportTicket>> watchTickets(String userId) => _tickets.stream.map((all) => all.where((t) => t.userId == userId).toList());

  @override
  Future<SupportTicket> createTicket({
    required String userId,
    required String subject,
    required String category,
    required String message,
    String? propertyId,
  }) async {
    await _latency();
    final now = DateTime.now();
    final t = SupportTicket(
      id: 'T-${1000 + _tickets.value.length + _rnd.nextInt(900)}',
      userId: userId,
      subject: subject,
      category: category,
      status: TicketStatus.open,
      createdAt: now,
      propertyId: propertyId,
      messages: [TicketMessage(fromSupport: false, text: message, sentAt: now)],
    );
    _tickets.value = [t, ..._tickets.value];
    Timer(const Duration(seconds: 5), () {
      _tickets.value = [
        for (final x in _tickets.value)
          x.id == t.id
              ? x.copyWith(
                  status: TicketStatus.inProgress,
                  messages: [
                    ...x.messages,
                    TicketMessage(
                      fromSupport: true,
                      text: 'Hi! Thanks for contacting StayFinder support. An agent is looking into this and will update you shortly.',
                      sentAt: DateTime.now(),
                    ),
                  ],
                )
              : x,
      ];
      _notify(userId, NotificationCategory.support, 'Support update', 'Ticket ${t.id} is now in progress.', link: '/support');
    });
    return t;
  }

  @override
  Future<void> replyToTicket(String id, String message) async {
    await _latency();
    _tickets.value = [
      for (final t in _tickets.value)
        t.id == id
            ? t.copyWith(
                status: TicketStatus.inProgress,
                messages: [
                  ...t.messages,
                  TicketMessage(fromSupport: false, text: message, sentAt: DateTime.now()),
                ],
              )
            : t,
    ];
  }
}

/// Adapter so notifications and chat can both expose `markRead`.
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._backend);
  final MockBackend _backend;

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) => _backend.watchNotifications(userId);
  @override
  Future<void> markRead(String id) => _backend.markNotificationRead(id);
  @override
  Future<void> markAllRead(String userId) => _backend.markAllRead(userId);
}
