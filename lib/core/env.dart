/// Build-time switches. Pass `--dart-define=DEMO=false` for production builds
/// once a real backend is wired in; demo hints and simulators are then hidden.
const kDemoMode = bool.fromEnvironment('DEMO', defaultValue: true);

/// Masked calling needs a paid telephony provider (e.g. Twilio Proxy).
/// While off, the Call buttons are hidden and seekers contact owners through
/// in-app chat only, so nobody's phone number is ever exposed.
/// StayFinder safety team line shown in SOS. Empty = hidden.
const kSafetyTeamPhone = String.fromEnvironment('SAFETY_PHONE');

const kMaskedCallingEnabled = bool.fromEnvironment('MASKED_CALLING', defaultValue: false);
