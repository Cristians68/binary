/// Tests for the external URLs the app can send a user to.
///
/// The certificate screen's "Add to LinkedIn" button, the share message, and
/// the domain printed on the certificate face all pointed at
/// `binaryacademy.app`, which does not resolve. Legal, Paywall and Profile
/// pointed at `binaryapp.org`, which does — and which is what App Store Connect
/// has on file for the privacy and support URLs.
///
/// A dead link is invisible from inside the app: `launchUrl` succeeds, because
/// handing the URL to the browser is all it promised to do. Nothing fails, and
/// the user lands on nothing. These tests are the only thing that can notice.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:binary/app_links.dart';

void main() {
  const liveHost = 'binaryapp.org';
  const deadHost = 'binaryacademy.app';

  final allUrls = <String, String>{
    'kSiteOrigin': kSiteOrigin,
    'kPrivacyUrl': kPrivacyUrl,
    'kTermsUrl': kTermsUrl,
    'kPurchaseTermsUrl': kPurchaseTermsUrl,
    'kSupportUrl': kSupportUrl,
    'kCertificateUrl': kCertificateUrl,
  };

  group('every link points at the host that exists', () {
    test('none of them use the dead domain', () {
      allUrls.forEach((name, url) {
        expect(url, isNot(contains(deadHost)),
            reason: '$name points at a domain that does not resolve');
      });
      expect(kSiteDisplayHost, isNot(contains(deadHost)));
    });

    test('all of them use the live domain', () {
      allUrls.forEach((name, url) {
        expect(url, contains(liveHost), reason: '$name left the site');
      });
      expect(kSiteDisplayHost, liveHost);
    });

    test('the displayed host matches the host actually linked to', () {
      // The certificate prints a bare domain and tells the reader to visit it.
      // If that text and the links diverge, one of them is wrong and only a
      // human reading both would ever catch it.
      expect(kSiteOrigin, endsWith(kSiteDisplayHost));
    });
  });

  group('shape', () {
    test('every URL is https', () {
      allUrls.forEach((name, url) {
        expect(url, startsWith('https://'), reason: '$name is not https');
      });
    });

    test('every URL parses and has a host', () {
      allUrls.forEach((name, url) {
        final uri = Uri.tryParse(url);
        expect(uri, isNotNull, reason: '$name is not a parsable URL');
        expect(uri!.host, isNotEmpty, reason: '$name has no host');
      });
    });

    test('the App Store Connect URLs are the exact paths filed there', () {
      // Apple checks these are reachable at review time. Changing a path here
      // without updating App Store Connect is a rejection.
      expect(kPrivacyUrl, 'https://$liveHost/privacy');
      expect(kSupportUrl, 'https://$liveHost/support');
    });

    test('the purchase terms link keeps its section fragment', () {
      expect(kPurchaseTermsUrl, startsWith(kTermsUrl));
      expect(Uri.parse(kPurchaseTermsUrl).fragment, 'in-app-purchases',
          reason: 'without the fragment this lands on the top of the page');
    });
  });
}
