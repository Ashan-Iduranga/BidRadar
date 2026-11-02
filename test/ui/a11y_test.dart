import 'dart:io';

import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/local/app_database.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/seed/sample_companies.dart';
import 'package:bidradar/domain/insights/insights.dart';
import 'package:bidradar/ui/approvals/approvals_page.dart';
import 'package:bidradar/ui/auth/sign_in_page.dart';
import 'package:bidradar/ui/deadlines/deadlines_page.dart';
import 'package:bidradar/ui/feed/feed_page.dart';
import 'package:bidradar/ui/feed/feed_view_model.dart';
import 'package:bidradar/ui/insights/insights_page.dart';
import 'package:bidradar/ui/insights/insights_view_model.dart';
import 'package:bidradar/ui/onboarding/onboarding_page.dart';
import 'package:bidradar/ui/onboarding/onboarding_view_model.dart';
import 'package:bidradar/ui/pipeline/bid_page.dart';
import 'package:bidradar/ui/pipeline/pipeline_page.dart';
import 'package:bidradar/ui/pipeline/pipeline_view_model.dart';
import 'package:bidradar/ui/scan/scan_page.dart';
import 'package:bidradar/ui/session/session_providers.dart';
import 'package:bidradar/ui/tender_detail/tender_detail_page.dart';
import 'package:bidradar/ui/tender_detail/tender_detail_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Accessibility checks on every page, in light and dark mode, with
/// realistic data: 48 dp tap targets, labelled controls, text contrast.
final now = DateTime.now();
final sample = SampleCompanies.parse(
  File('assets/seed/sample_companies.json').readAsStringSync(),
).first;

Tender tender(String id, {int days = 6, String country = 'LKA'}) => Tender(
  source: TenderSourceType.worldBank,
  sourceId: id,
  title: 'Supply and installation of a patient records system $id',
  buyer: 'Ministry of Health',
  country: country,
  cpvCodes: const ['72200000'],
  deadline: now.add(Duration(days: days)),
  estimatedValue: 250000,
  currency: 'USD',
  noticeText: 'Bidders must hold ISO 9001 certification. ' * 20,
  textHash: 'h$id',
  url: 'https://example.org/$id',
  fetchedAt: now,
);

final verdict = Verdict(
  id: 'v1',
  tenderId: 'worldbank_1',
  companyId: sample.company.id,
  verdict: VerdictKind.bid,
  fitScore: 82,
  confidence: 0.86,
  criteria: const [
    Criterion(
      criterion: 'ISO 9001 certification',
      quote: 'Bidders must hold ISO 9001 certification.',
      met: CriterionMet.yes,
      quoteVerified: true,
    ),
  ],
  missingDocs: const ['ISO 9001 certificate copy'],
  clarificationQuestion: 'Is a joint venture allowed?',
  rulesResult: const RulesResult.pass(),
  status: VerdictStatus.accepted,
  model: 'gemini',
  at: now,
);

Bid bid(String id, BidStage stage, {ApprovalState a = ApprovalState.none}) =>
    Bid(
      id: id,
      tenderId: 'worldbank_$id',
      companyId: sample.company.id,
      stage: stage,
      ownerUid: 'u1',
      title: 'Patient records system $id',
      buyer: 'Ministry of Health',
      deadline: now.add(const Duration(days: 5)),
      verdict: VerdictKind.bid,
      fitScore: 82,
      approval: a,
      tasks: const [
        BidTask(id: 't1', title: 'Prepare: ISO 9001 certificate copy'),
        BidTask(id: 't2', title: 'Price the offer', done: true),
      ],
      lossReasons: stage == BidStage.lost ? const ['Price too high'] : const [],
      updatedAt: now,
    );

final bids = [
  bid('1', BidStage.watching, a: ApprovalState.pending),
  bid('2', BidStage.preparing, a: ApprovalState.approved),
  bid('3', BidStage.lost, a: ApprovalState.approved),
];

final common = [
  currentCompanyIdProvider.overrideWith((ref) => Stream.value('c')),
  currentCompanyProvider.overrideWith((ref) => Stream.value(sample.company)),
  currentProfileProvider.overrideWith((ref) => Stream.value(sample.profile)),
  currentRoleProvider.overrideWithValue(UserRole.owner),
  bidsProvider.overrideWith((ref) => Stream.value(bids)),
  approvalsProvider.overrideWith(
    (ref) => Stream.value([
      Approval(
        id: 'a1',
        bidId: '2',
        companyId: 'c',
        decision: ApprovalDecision.approved,
        byUid: 'u1',
        note: 'Go',
        at: now,
      ),
    ]),
  ),
  lastSyncProvider.overrideWith(
    (ref) => Stream.value(SyncReport(ranAt: now.toUtc())),
  ),
  feedItemsProvider.overrideWithValue(
    AsyncData([
      FeedItem(tender('1'), const RulesResult.pass(), verdict),
      FeedItem(
        tender('2', days: 2),
        const RulesResult(
          vetoes: [],
          warnings: ['Closes in less than 72 hours.'],
        ),
      ),
      FeedItem(
        tender('3', country: 'ESP'),
        const RulesResult(
          vetoes: [
            RuleVeto(
              rule: VetoRule.countryNotServed,
              message: 'You do not deliver in Spain (ESP).',
            ),
          ],
        ),
      ),
    ]),
  ),
  tenderDetailProvider('worldbank_1').overrideWithValue(
    AsyncData(
      TenderDetail(
        tender: tender('1'),
        rules: const RulesResult.pass(),
        verdict: verdict,
      ),
    ),
  ),
  bidProvider('2').overrideWith((ref) => Stream.value(bids[1])),
  insightsProvider.overrideWithValue(
    InsightsStats.compute(bids: bids, judged: [(tender('1'), verdict)]),
  ),
  onboardingViewModelProvider.overrideWith(_FakeOnboarding.new),
];

class _FakeOnboarding extends OnboardingViewModel {
  @override
  Future<OnboardingData> build() async => OnboardingData(
    invite: null,
    samples: SampleCompanies.parse(
      File('assets/seed/sample_companies.json').readAsStringSync(),
    ),
  );
}

final pages = <String, Widget Function()>{
  'Sign in': () => const SignInPage(),
  'Onboarding': () => const OnboardingPage(),
  'Feed': () => const FeedPage(),
  'Tender detail': () => const TenderDetailPage(tenderId: 'worldbank_1'),
  'Pipeline': () => const PipelinePage(),
  'Bid': () => const BidPage(bidId: '2'),
  'Approvals': () => const ApprovalsPage(),
  'Deadlines': () => const DeadlinesPage(),
  'Insights': () => const InsightsPage(),
  'Scan': () => const ScanPage(),
};

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    for (final MapEntry(key: name, value: build) in pages.entries) {
      testWidgets('$name ($mode) meets the a11y guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          ProviderScope(
            overrides: common,
            child: MaterialApp(theme: theme, home: build()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
        // Unmount so page timers (e.g. the feed's minute tick) stop.
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
