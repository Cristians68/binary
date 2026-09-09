/// Every external URL the app can send a user to.
///
/// WHY THIS EXISTS
/// ---------------
/// These were string literals spread across four screens, and they had already
/// drifted apart. The Legal, Paywall and Profile screens pointed at
/// `binaryapp.org` — which is live, and is the domain filed with App Store
/// Connect for the privacy and support URLs. The certificate screen's
/// "Add to LinkedIn" button pointed at `binaryacademy.app`, which does not
/// resolve at all: the button opened LinkedIn with a certificate URL leading
/// to nothing, on the one screen a user is most likely to share publicly.
///
/// A dead link is not a visible failure. `launchUrl` succeeds — it handed the
/// URL to the browser exactly as asked — so nothing in the app can tell that
/// the destination is gone. Keeping the host in one place is the only thing
/// that makes a second copy impossible to get wrong.
library;

/// The marketing/legal site. Also what App Store Connect has on file.
const String kSiteOrigin = 'https://binaryapp.org';

/// Privacy policy. Declared in App Store Connect; must stay reachable.
const String kPrivacyUrl = '$kSiteOrigin/privacy';

/// Terms of service.
const String kTermsUrl = '$kSiteOrigin/terms';

/// The in-app purchase section of the terms.
///
/// The `#in-app-purchases` fragment is a real `id` on that page
/// (`site/terms.html`). If the section is ever renamed, this silently becomes
/// a link to the top of the page instead.
const String kPurchaseTermsUrl = '$kTermsUrl#in-app-purchases';

/// Support page. Declared in App Store Connect as the support URL.
const String kSupportUrl = '$kSiteOrigin/support';

/// The certificate landing page shared to LinkedIn and in the share sheet.
const String kCertificateUrl = kSiteOrigin;

/// The site shown as bare text — on the certificate face and in the share
/// message. Both read as an instruction to visit it, so it has to be a domain
/// that exists.
const String kSiteDisplayHost = 'binaryapp.org';
