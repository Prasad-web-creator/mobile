import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ta'),
  ];

  /// No description provided for @analysisAcceptContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept and continue'**
  String get analysisAcceptContinue;

  /// No description provided for @analysisAddDocumentFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add this document. Try again.'**
  String get analysisAddDocumentFailed;

  /// No description provided for @analysisAddMethods.
  ///
  /// In en, this message translates to:
  /// **'Scan, upload or pick a photo'**
  String get analysisAddMethods;

  /// No description provided for @analysisAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add new'**
  String get analysisAddNew;

  /// No description provided for @analysisAddPolicy.
  ///
  /// In en, this message translates to:
  /// **'Add a policy'**
  String get analysisAddPolicy;

  /// No description provided for @analysisAddPrescription.
  ///
  /// In en, this message translates to:
  /// **'Add a prescription'**
  String get analysisAddPrescription;

  /// No description provided for @analysisAlreadySaved.
  ///
  /// In en, this message translates to:
  /// **'Already saved'**
  String get analysisAlreadySaved;

  /// No description provided for @analysisAlsoConsidered.
  ///
  /// In en, this message translates to:
  /// **'Also considered'**
  String get analysisAlsoConsidered;

  /// No description provided for @analysisAnalysisBasis.
  ///
  /// In en, this message translates to:
  /// **'Analysis basis'**
  String get analysisAnalysisBasis;

  /// No description provided for @analysisAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analysisAnalyzing;

  /// No description provided for @analysisAnswerAbove.
  ///
  /// In en, this message translates to:
  /// **'Please answer the questions above to continue.'**
  String get analysisAnswerAbove;

  /// No description provided for @analysisAnswerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Answer question'**
  String get analysisAnswerQuestion;

  /// No description provided for @analysisAnswerQuestions.
  ///
  /// In en, this message translates to:
  /// **'Answer questions'**
  String get analysisAnswerQuestions;

  /// No description provided for @analysisAnswerToComplete.
  ///
  /// In en, this message translates to:
  /// **'Answer to complete your coverage analysis.'**
  String get analysisAnswerToComplete;

  /// No description provided for @analysisAnswersUsed.
  ///
  /// In en, this message translates to:
  /// **'Your answers that were used in this analysis'**
  String get analysisAnswersUsed;

  /// No description provided for @analysisAppliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies to: '**
  String get analysisAppliesTo;

  /// No description provided for @analysisAskedThisPolicy.
  ///
  /// In en, this message translates to:
  /// **'Asked about this policy'**
  String get analysisAskedThisPolicy;

  /// No description provided for @analysisBackDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to Dashboard'**
  String get analysisBackDashboard;

  /// No description provided for @analysisBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get analysisBackHome;

  /// No description provided for @analysisBackTreatment.
  ///
  /// In en, this message translates to:
  /// **'Back to treatment'**
  String get analysisBackTreatment;

  /// No description provided for @analysisBeforeBegin.
  ///
  /// In en, this message translates to:
  /// **'Before we begin'**
  String get analysisBeforeBegin;

  /// No description provided for @analysisBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get analysisBest;

  /// No description provided for @analysisCalendar.
  ///
  /// In en, this message translates to:
  /// **'Open calendar'**
  String get analysisCalendar;

  /// No description provided for @analysisCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get analysisCancel;

  /// No description provided for @analysisCancelAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Cancel analysis'**
  String get analysisCancelAnalysis;

  /// No description provided for @analysisCapitalInvalidPolicy.
  ///
  /// In en, this message translates to:
  /// **'Invalid Policy'**
  String get analysisCapitalInvalidPolicy;

  /// No description provided for @analysisCapitalNeedsVerification.
  ///
  /// In en, this message translates to:
  /// **'Needs Verification'**
  String get analysisCapitalNeedsVerification;

  /// No description provided for @analysisCapitalNotCovered.
  ///
  /// In en, this message translates to:
  /// **'Not Covered'**
  String get analysisCapitalNotCovered;

  /// No description provided for @analysisCapitalPolicyEvidence.
  ///
  /// In en, this message translates to:
  /// **'Policy Evidence'**
  String get analysisCapitalPolicyEvidence;

  /// No description provided for @analysisCheckCancelled.
  ///
  /// In en, this message translates to:
  /// **'This check was cancelled'**
  String get analysisCheckCancelled;

  /// No description provided for @analysisCheckDetails.
  ///
  /// In en, this message translates to:
  /// **'Check details'**
  String get analysisCheckDetails;

  /// No description provided for @analysisCheckDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'An estimate from your documents. Your insurer makes the final decision.'**
  String get analysisCheckDisclaimer;

  /// No description provided for @analysisCheckExpired.
  ///
  /// In en, this message translates to:
  /// **'This check expired'**
  String get analysisCheckExpired;

  /// No description provided for @analysisCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed'**
  String get analysisCheckFailed;

  /// No description provided for @analysisCheckNotFound.
  ///
  /// In en, this message translates to:
  /// **'Check not found.'**
  String get analysisCheckNotFound;

  /// No description provided for @analysisCheckNotStarted.
  ///
  /// In en, this message translates to:
  /// **'This check hasn’t started'**
  String get analysisCheckNotStarted;

  /// No description provided for @analysisChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get analysisChecking;

  /// No description provided for @analysisCheckingPolicies.
  ///
  /// In en, this message translates to:
  /// **'Checking your policies…'**
  String get analysisCheckingPolicies;

  /// No description provided for @analysisClaimDate.
  ///
  /// In en, this message translates to:
  /// **'Claim Date'**
  String get analysisClaimDate;

  /// No description provided for @analysisClarificationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Clarification Needed'**
  String get analysisClarificationNeeded;

  /// No description provided for @analysisClauseLabel.
  ///
  /// In en, this message translates to:
  /// **'Clause: '**
  String get analysisClauseLabel;

  /// No description provided for @analysisComplete.
  ///
  /// In en, this message translates to:
  /// **'Analysis Complete!'**
  String get analysisComplete;

  /// No description provided for @analysisConditionalCover.
  ///
  /// In en, this message translates to:
  /// **'Coverage for these items depends on a detail that must be confirmed.'**
  String get analysisConditionalCover;

  /// No description provided for @analysisConflicts.
  ///
  /// In en, this message translates to:
  /// **'Conflicts'**
  String get analysisConflicts;

  /// No description provided for @analysisConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the server and preparing analysis…'**
  String get analysisConnecting;

  /// No description provided for @analysisConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the Terms & Conditions.'**
  String get analysisConsentAgree;

  /// No description provided for @analysisConsentClaims.
  ///
  /// In en, this message translates to:
  /// **'I understand that the system does not submit insurance claims.'**
  String get analysisConsentClaims;

  /// No description provided for @analysisConsentInformation.
  ///
  /// In en, this message translates to:
  /// **'I understand that the analysis is for informational purposes only.'**
  String get analysisConsentInformation;

  /// No description provided for @analysisConsentInsurer.
  ///
  /// In en, this message translates to:
  /// **'I understand that the insurance provider makes the final approval decision.'**
  String get analysisConsentInsurer;

  /// No description provided for @analysisConsentOcr.
  ///
  /// In en, this message translates to:
  /// **'I agree that Policy Pal may store my uploaded documents, read them with OCR, and send extracted text and any details I enter to Google Gemini for coverage analysis.'**
  String get analysisConsentOcr;

  /// No description provided for @analysisConsentOwnership.
  ///
  /// In en, this message translates to:
  /// **'I confirm that the uploaded documents belong to me or I have permission to use them.'**
  String get analysisConsentOwnership;

  /// No description provided for @analysisConsentReference.
  ///
  /// In en, this message translates to:
  /// **'I agree that the generated report is only a reference.'**
  String get analysisConsentReference;

  /// No description provided for @analysisConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Consent & Agreement'**
  String get analysisConsentTitle;

  /// No description provided for @analysisConsideredClauses.
  ///
  /// In en, this message translates to:
  /// **'Policy Clauses Considered'**
  String get analysisConsideredClauses;

  /// No description provided for @analysisContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get analysisContinue;

  /// No description provided for @analysisContinuity.
  ///
  /// In en, this message translates to:
  /// **'Policy Continuity'**
  String get analysisContinuity;

  /// No description provided for @analysisContinuityStatus.
  ///
  /// In en, this message translates to:
  /// **'Continuity Status'**
  String get analysisContinuityStatus;

  /// No description provided for @analysisContinuityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Continuity Cannot Be Established'**
  String get analysisContinuityUnknown;

  /// No description provided for @analysisCopyCheckSummary.
  ///
  /// In en, this message translates to:
  /// **'Copy check summary'**
  String get analysisCopyCheckSummary;

  /// No description provided for @analysisCouldNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Analysis could not be completed'**
  String get analysisCouldNotComplete;

  /// No description provided for @analysisCouldNotFinish.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish this check'**
  String get analysisCouldNotFinish;

  /// No description provided for @analysisCouldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read'**
  String get analysisCouldNotRead;

  /// No description provided for @analysisCoverRestarted.
  ///
  /// In en, this message translates to:
  /// **'Cover Restarted'**
  String get analysisCoverRestarted;

  /// No description provided for @analysisCoverage.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get analysisCoverage;

  /// No description provided for @analysisCoverageAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Coverage Analysis'**
  String get analysisCoverageAnalysis;

  /// No description provided for @analysisCoverageBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Coverage Breakdown'**
  String get analysisCoverageBreakdown;

  /// No description provided for @analysisCoverageGaps.
  ///
  /// In en, this message translates to:
  /// **'Coverage Gap(s)'**
  String get analysisCoverageGaps;

  /// No description provided for @analysisCoverageSummary.
  ///
  /// In en, this message translates to:
  /// **'Coverage Summary'**
  String get analysisCoverageSummary;

  /// No description provided for @analysisCovered.
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get analysisCovered;

  /// No description provided for @analysisCurrentPeriod.
  ///
  /// In en, this message translates to:
  /// **'Current Period'**
  String get analysisCurrentPeriod;

  /// No description provided for @analysisDateExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., 15-Feb-2026 (or tap calendar)'**
  String get analysisDateExample;

  /// No description provided for @analysisDateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Date unavailable'**
  String get analysisDateUnavailable;

  /// No description provided for @analysisDecidingClauses.
  ///
  /// In en, this message translates to:
  /// **'Deciding clauses'**
  String get analysisDecidingClauses;

  /// No description provided for @analysisDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Primary Diagnosis'**
  String get analysisDiagnosis;

  /// No description provided for @analysisDisclaimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer: '**
  String get analysisDisclaimerLabel;

  /// No description provided for @analysisDistribution.
  ///
  /// In en, this message translates to:
  /// **'Coverage Distribution'**
  String get analysisDistribution;

  /// No description provided for @analysisDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get analysisDoctor;

  /// No description provided for @analysisDocumentConsent.
  ///
  /// In en, this message translates to:
  /// **'I have permission to use this document. I agree that Policy Pal may store it and read it with OCR and send extracted text to Google Gemini for analysis. The result is for reference. Policy Pal does not submit a claim, and only the insurer can approve it.'**
  String get analysisDocumentConsent;

  /// No description provided for @analysisDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get analysisDocuments;

  /// No description provided for @analysisDocumentsAnalysed.
  ///
  /// In en, this message translates to:
  /// **'Documents Analysed'**
  String get analysisDocumentsAnalysed;

  /// No description provided for @analysisDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get analysisDone;

  /// No description provided for @analysisEnded.
  ///
  /// In en, this message translates to:
  /// **'Analysis ended'**
  String get analysisEnded;

  /// No description provided for @analysisEnterDate.
  ///
  /// In en, this message translates to:
  /// **'Or enter date (e.g. 15-Feb-2026)'**
  String get analysisEnterDate;

  /// No description provided for @analysisEstimatedCost.
  ///
  /// In en, this message translates to:
  /// **'Est. Cost'**
  String get analysisEstimatedCost;

  /// No description provided for @analysisExtractedDetails.
  ///
  /// In en, this message translates to:
  /// **'Details extracted from your policy and prescription'**
  String get analysisExtractedDetails;

  /// No description provided for @analysisExtractingPdf.
  ///
  /// In en, this message translates to:
  /// **'Extracting PDF Text'**
  String get analysisExtractingPdf;

  /// No description provided for @analysisExtractingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Extracting Policy Data'**
  String get analysisExtractingPolicy;

  /// No description provided for @analysisExtractingPrescription.
  ///
  /// In en, this message translates to:
  /// **'Extracting Prescription Data'**
  String get analysisExtractingPrescription;

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis Failed'**
  String get analysisFailed;

  /// No description provided for @analysisFinancialStatus.
  ///
  /// In en, this message translates to:
  /// **'Financial Status'**
  String get analysisFinancialStatus;

  /// No description provided for @analysisFirstStartDate.
  ///
  /// In en, this message translates to:
  /// **'First Start Date'**
  String get analysisFirstStartDate;

  /// No description provided for @analysisFollowingAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Following the analysis…'**
  String get analysisFollowingAnalysis;

  /// No description provided for @analysisGeneratingReport.
  ///
  /// In en, this message translates to:
  /// **'Generating Report'**
  String get analysisGeneratingReport;

  /// No description provided for @analysisGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get analysisGoHome;

  /// No description provided for @analysisHighlightCategory.
  ///
  /// In en, this message translates to:
  /// **'Tap a category to highlight it'**
  String get analysisHighlightCategory;

  /// No description provided for @analysisHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get analysisHistory;

  /// No description provided for @analysisHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get analysisHospital;

  /// No description provided for @analysisHospitalization.
  ///
  /// In en, this message translates to:
  /// **'Hospitalization'**
  String get analysisHospitalization;

  /// No description provided for @analysisHowClassified.
  ///
  /// In en, this message translates to:
  /// **'How the prescribed items were classified'**
  String get analysisHowClassified;

  /// No description provided for @analysisImageBasedPdf.
  ///
  /// In en, this message translates to:
  /// **'Your uploaded PDF is image-based, so it may take some time. Please stay here.'**
  String get analysisImageBasedPdf;

  /// No description provided for @analysisInsurer.
  ///
  /// In en, this message translates to:
  /// **'Insurance Provider'**
  String get analysisInsurer;

  /// No description provided for @analysisInvalidBoth.
  ///
  /// In en, this message translates to:
  /// **'Invalid Policy and Prescription'**
  String get analysisInvalidBoth;

  /// No description provided for @analysisInvalidBothHint.
  ///
  /// In en, this message translates to:
  /// **'The uploaded Policy and Prescription documents could not be analyzed because they are invalid, unreadable, or unsupported. Please ensure you upload a valid health insurance policy and a medical prescription document (PDF, JPG, PNG) and try again.'**
  String get analysisInvalidBothHint;

  /// No description provided for @analysisInvalidDocHint.
  ///
  /// In en, this message translates to:
  /// **'The uploaded document(s) could not be analyzed because they are invalid or unsupported. Please ensure you upload valid health insurance policy and medical prescription documents and try again.'**
  String get analysisInvalidDocHint;

  /// No description provided for @analysisInvalidDocument.
  ///
  /// In en, this message translates to:
  /// **'Invalid Document'**
  String get analysisInvalidDocument;

  /// No description provided for @analysisInvalidPolicy.
  ///
  /// In en, this message translates to:
  /// **'Invalid policy'**
  String get analysisInvalidPolicy;

  /// No description provided for @analysisInvalidPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'The uploaded Policy document could not be analyzed because it is invalid, unreadable, or unsupported. Please ensure you upload a valid health insurance policy document (PDF, JPG, PNG) and try again.'**
  String get analysisInvalidPolicyHint;

  /// No description provided for @analysisInvalidPolicyReason.
  ///
  /// In en, this message translates to:
  /// **'The uploaded policy document contains no recognizable insurance policy clauses, covered treatments, benefit rules, or insurance terms.'**
  String get analysisInvalidPolicyReason;

  /// No description provided for @analysisInvalidPrescription.
  ///
  /// In en, this message translates to:
  /// **'Invalid Prescription'**
  String get analysisInvalidPrescription;

  /// No description provided for @analysisInvalidPrescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'The uploaded Prescription document could not be analyzed because it is invalid, unreadable, or unsupported. Please ensure you upload a valid medical prescription document (PDF, JPG, PNG) and try again.'**
  String get analysisInvalidPrescriptionHint;

  /// No description provided for @analysisInvalidRxReason.
  ///
  /// In en, this message translates to:
  /// **'The uploaded document contains no valid diagnosis, medicines, medical tests, procedures, or symptoms.'**
  String get analysisInvalidRxReason;

  /// No description provided for @analysisInvalidTypedHint.
  ///
  /// In en, this message translates to:
  /// **'The self-entered prescription is not valid. Please provide valid medical details (such as diagnosis, symptoms, diseases, medicines, or medical tests) and try again.'**
  String get analysisInvalidTypedHint;

  /// No description provided for @analysisInvalidTypedReason.
  ///
  /// In en, this message translates to:
  /// **'The self-entered text contains no recognizable medical details (no diagnosis, symptoms, diseases, medicines, or medical tests).'**
  String get analysisInvalidTypedReason;

  /// No description provided for @analysisItemDecision.
  ///
  /// In en, this message translates to:
  /// **'Item-wise Coverage Decision'**
  String get analysisItemDecision;

  /// No description provided for @analysisItemReason.
  ///
  /// In en, this message translates to:
  /// **'Result and reason for each prescribed item'**
  String get analysisItemReason;

  /// No description provided for @analysisKeepAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Keep analyzing'**
  String get analysisKeepAnalyzing;

  /// No description provided for @analysisKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'Please keep this screen open'**
  String get analysisKeepOpen;

  /// No description provided for @analysisKeptSavedPolicy.
  ///
  /// In en, this message translates to:
  /// **'Kept your saved policy.'**
  String get analysisKeptSavedPolicy;

  /// No description provided for @analysisLoadCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this check.'**
  String get analysisLoadCheckFailed;

  /// No description provided for @analysisLoadChecksFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load checks.'**
  String get analysisLoadChecksFailed;

  /// No description provided for @analysisLoadDetailsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load these details.'**
  String get analysisLoadDetailsFailed;

  /// No description provided for @analysisLoadPoliciesFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your saved policies.'**
  String get analysisLoadPoliciesFailed;

  /// No description provided for @analysisLoadPolicyReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this policy\'s report.'**
  String get analysisLoadPolicyReportFailed;

  /// No description provided for @analysisLoadPrescriptionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your saved treatment documents.'**
  String get analysisLoadPrescriptionsFailed;

  /// No description provided for @analysisLoadPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the document preview.'**
  String get analysisLoadPreviewFailed;

  /// No description provided for @analysisLoadReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the report'**
  String get analysisLoadReportFailed;

  /// No description provided for @analysisLoadingReport.
  ///
  /// In en, this message translates to:
  /// **'Loading coverage report…'**
  String get analysisLoadingReport;

  /// No description provided for @analysisLoadingSummary.
  ///
  /// In en, this message translates to:
  /// **'Loading Coverage Summary...'**
  String get analysisLoadingSummary;

  /// No description provided for @analysisLooksPolicy.
  ///
  /// In en, this message translates to:
  /// **'This looks like a policy'**
  String get analysisLooksPolicy;

  /// No description provided for @analysisLooksPrescription.
  ///
  /// In en, this message translates to:
  /// **'This looks like a prescription'**
  String get analysisLooksPrescription;

  /// No description provided for @analysisMajorTermReason.
  ///
  /// In en, this message translates to:
  /// **'Policy terms that led to this result'**
  String get analysisMajorTermReason;

  /// No description provided for @analysisMajorTerms.
  ///
  /// In en, this message translates to:
  /// **'Major Policy Terms – Not Covered'**
  String get analysisMajorTerms;

  /// No description provided for @analysisMaxClaim.
  ///
  /// In en, this message translates to:
  /// **'Max Claim'**
  String get analysisMaxClaim;

  /// No description provided for @analysisMissingInfo.
  ///
  /// In en, this message translates to:
  /// **'Information Not Available'**
  String get analysisMissingInfo;

  /// No description provided for @analysisMissingUploads.
  ///
  /// In en, this message translates to:
  /// **'Missing uploaded files or policy selection.'**
  String get analysisMissingUploads;

  /// No description provided for @analysisNeedMoreInformation.
  ///
  /// In en, this message translates to:
  /// **'We need a little more information'**
  String get analysisNeedMoreInformation;

  /// No description provided for @analysisNeedsInfo.
  ///
  /// In en, this message translates to:
  /// **'Needs info'**
  String get analysisNeedsInfo;

  /// No description provided for @analysisNeedsInput.
  ///
  /// In en, this message translates to:
  /// **'Needs your input'**
  String get analysisNeedsInput;

  /// No description provided for @analysisNeedsVerification.
  ///
  /// In en, this message translates to:
  /// **'Needs verification'**
  String get analysisNeedsVerification;

  /// No description provided for @analysisNewFirstYear.
  ///
  /// In en, this message translates to:
  /// **'New policy (first year)'**
  String get analysisNewFirstYear;

  /// No description provided for @analysisNewPolicy.
  ///
  /// In en, this message translates to:
  /// **'New policy'**
  String get analysisNewPolicy;

  /// No description provided for @analysisNewPrescription.
  ///
  /// In en, this message translates to:
  /// **'New prescription'**
  String get analysisNewPrescription;

  /// No description provided for @analysisNewRenewed.
  ///
  /// In en, this message translates to:
  /// **'New / Renewed'**
  String get analysisNewRenewed;

  /// No description provided for @analysisNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get analysisNo;

  /// No description provided for @analysisNoChecks.
  ///
  /// In en, this message translates to:
  /// **'No checks yet'**
  String get analysisNoChecks;

  /// No description provided for @analysisNoChecksFilter.
  ///
  /// In en, this message translates to:
  /// **'No checks match this filter.'**
  String get analysisNoChecksFilter;

  /// No description provided for @analysisNoEvaluatedClaims.
  ///
  /// In en, this message translates to:
  /// **'No evaluated claim items available.'**
  String get analysisNoEvaluatedClaims;

  /// No description provided for @analysisNoExactWording.
  ///
  /// In en, this message translates to:
  /// **'Exact policy wording is unavailable for this term.'**
  String get analysisNoExactWording;

  /// No description provided for @analysisNoGapsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'None found in the documents provided (history incomplete).'**
  String get analysisNoGapsIncomplete;

  /// No description provided for @analysisNoQuestionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No question is available yet.'**
  String get analysisNoQuestionAvailable;

  /// No description provided for @analysisNoneFound.
  ///
  /// In en, this message translates to:
  /// **'None found.'**
  String get analysisNoneFound;

  /// No description provided for @analysisNormalizing.
  ///
  /// In en, this message translates to:
  /// **'Cleaning & Normalizing'**
  String get analysisNormalizing;

  /// No description provided for @analysisNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get analysisNotAvailable;

  /// No description provided for @analysisNotCovered.
  ///
  /// In en, this message translates to:
  /// **'Not covered'**
  String get analysisNotCovered;

  /// No description provided for @analysisNotEstablished.
  ///
  /// In en, this message translates to:
  /// **'Not established'**
  String get analysisNotEstablished;

  /// No description provided for @analysisNotRequired.
  ///
  /// In en, this message translates to:
  /// **'Not Required'**
  String get analysisNotRequired;

  /// No description provided for @analysisNotStated.
  ///
  /// In en, this message translates to:
  /// **'Not stated'**
  String get analysisNotStated;

  /// No description provided for @analysisOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline.'**
  String get analysisOffline;

  /// No description provided for @analysisOfflineSaved.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing saved checks.'**
  String get analysisOfflineSaved;

  /// No description provided for @analysisOnePolicyQuestions.
  ///
  /// In en, this message translates to:
  /// **'These questions are about one policy only.'**
  String get analysisOnePolicyQuestions;

  /// No description provided for @analysisOtherPolicies.
  ///
  /// In en, this message translates to:
  /// **'Your other policies are unaffected.'**
  String get analysisOtherPolicies;

  /// No description provided for @analysisPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get analysisPartial;

  /// No description provided for @analysisPartiallyCovered.
  ///
  /// In en, this message translates to:
  /// **'Partially Covered'**
  String get analysisPartiallyCovered;

  /// No description provided for @analysisPartlyCovered.
  ///
  /// In en, this message translates to:
  /// **'Partly covered'**
  String get analysisPartlyCovered;

  /// No description provided for @analysisPatientName.
  ///
  /// In en, this message translates to:
  /// **'Patient Name'**
  String get analysisPatientName;

  /// No description provided for @analysisPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get analysisPhotos;

  /// No description provided for @analysisPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from your gallery'**
  String get analysisPickGallery;

  /// No description provided for @analysisPolicies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get analysisPolicies;

  /// No description provided for @analysisPolicy.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get analysisPolicy;

  /// No description provided for @analysisPolicyAlreadySaved.
  ///
  /// In en, this message translates to:
  /// **'Policy already saved'**
  String get analysisPolicyAlreadySaved;

  /// No description provided for @analysisPolicyClause.
  ///
  /// In en, this message translates to:
  /// **'Policy clause'**
  String get analysisPolicyClause;

  /// No description provided for @analysisPolicyClauses.
  ///
  /// In en, this message translates to:
  /// **'Policy clauses'**
  String get analysisPolicyClauses;

  /// No description provided for @analysisPolicyComparison.
  ///
  /// In en, this message translates to:
  /// **'Policy Comparison'**
  String get analysisPolicyComparison;

  /// No description provided for @analysisPolicyEvidence.
  ///
  /// In en, this message translates to:
  /// **'Policy evidence'**
  String get analysisPolicyEvidence;

  /// No description provided for @analysisPolicyName.
  ///
  /// In en, this message translates to:
  /// **'Policy Name'**
  String get analysisPolicyName;

  /// No description provided for @analysisPolicyNumber.
  ///
  /// In en, this message translates to:
  /// **'Policy Number'**
  String get analysisPolicyNumber;

  /// No description provided for @analysisPolicySummary.
  ///
  /// In en, this message translates to:
  /// **'Policy Summary'**
  String get analysisPolicySummary;

  /// No description provided for @analysisPolicyType.
  ///
  /// In en, this message translates to:
  /// **'Policy Type'**
  String get analysisPolicyType;

  /// No description provided for @analysisPolicyWordingUsed.
  ///
  /// In en, this message translates to:
  /// **'Policy wording used'**
  String get analysisPolicyWordingUsed;

  /// No description provided for @analysisPrescribedDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Prescribed Treatment / Diagnosis'**
  String get analysisPrescribedDiagnosis;

  /// No description provided for @analysisPrescribedTreatment.
  ///
  /// In en, this message translates to:
  /// **'Prescribed Treatment'**
  String get analysisPrescribedTreatment;

  /// No description provided for @analysisPrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get analysisPrescription;

  /// No description provided for @analysisPrescriptionSummary.
  ///
  /// In en, this message translates to:
  /// **'Prescription Summary'**
  String get analysisPrescriptionSummary;

  /// No description provided for @analysisProgress.
  ///
  /// In en, this message translates to:
  /// **'Analysis progress'**
  String get analysisProgress;

  /// No description provided for @analysisQa.
  ///
  /// In en, this message translates to:
  /// **'Clarification Q&A'**
  String get analysisQa;

  /// No description provided for @analysisReadImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the document image.'**
  String get analysisReadImageFailed;

  /// No description provided for @analysisReadingCoverage.
  ///
  /// In en, this message translates to:
  /// **'Our system is reading your documents and cross-referencing coverage.'**
  String get analysisReadingCoverage;

  /// No description provided for @analysisReadingDocuments.
  ///
  /// In en, this message translates to:
  /// **'Reading your documents…'**
  String get analysisReadingDocuments;

  /// No description provided for @analysisReanalyzing.
  ///
  /// In en, this message translates to:
  /// **'Re-analyzing with your answers...'**
  String get analysisReanalyzing;

  /// No description provided for @analysisRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Your check can keep running.'**
  String get analysisRefreshFailed;

  /// No description provided for @analysisRenewalGap.
  ///
  /// In en, this message translates to:
  /// **'Policy renewal break / gap'**
  String get analysisRenewalGap;

  /// No description provided for @analysisRenewedPolicy.
  ///
  /// In en, this message translates to:
  /// **'Renewed policy'**
  String get analysisRenewedPolicy;

  /// No description provided for @analysisReportedSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Reported Symptoms'**
  String get analysisReportedSymptoms;

  /// No description provided for @analysisRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get analysisRequired;

  /// No description provided for @analysisResultUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Result not available'**
  String get analysisResultUnavailable;

  /// No description provided for @analysisRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get analysisRetry;

  /// No description provided for @analysisRetryAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Retry Analysis'**
  String get analysisRetryAnalysis;

  /// No description provided for @analysisReturnDashboard.
  ///
  /// In en, this message translates to:
  /// **'Return to Dashboard'**
  String get analysisReturnDashboard;

  /// No description provided for @analysisReviewTerms.
  ///
  /// In en, this message translates to:
  /// **'Please review and accept the Terms & Conditions before the system analyzes your uploaded documents.'**
  String get analysisReviewTerms;

  /// No description provided for @analysisRunningRules.
  ///
  /// In en, this message translates to:
  /// **'Running Business Rules'**
  String get analysisRunningRules;

  /// No description provided for @analysisSaveAnswerFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your answer. Try again.'**
  String get analysisSaveAnswerFailed;

  /// No description provided for @analysisSaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get analysisSaveAnyway;

  /// No description provided for @analysisSaveConsentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save consent. Please try again.'**
  String get analysisSaveConsentFailed;

  /// No description provided for @analysisSaveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save another copy'**
  String get analysisSaveCopy;

  /// No description provided for @analysisSaveMisplacedPolicy.
  ///
  /// In en, this message translates to:
  /// **'You selected a policy document in the prescription step. Save it to your Policies list instead?'**
  String get analysisSaveMisplacedPolicy;

  /// No description provided for @analysisSaveMisplacedPrescription.
  ///
  /// In en, this message translates to:
  /// **'You selected a prescription document in the policy step. Save it to your Prescriptions list instead?'**
  String get analysisSaveMisplacedPrescription;

  /// No description provided for @analysisSaveToPolicies.
  ///
  /// In en, this message translates to:
  /// **'Save to Policies'**
  String get analysisSaveToPolicies;

  /// No description provided for @analysisSaveToPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Save to Prescriptions'**
  String get analysisSaveToPrescriptions;

  /// No description provided for @analysisSavedToPolicies.
  ///
  /// In en, this message translates to:
  /// **'Saved to your Policies list.'**
  String get analysisSavedToPolicies;

  /// No description provided for @analysisSavedToPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Saved to your Prescriptions list.'**
  String get analysisSavedToPrescriptions;

  /// No description provided for @analysisScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get analysisScan;

  /// No description provided for @analysisSeeClauses.
  ///
  /// In en, this message translates to:
  /// **'See policy clauses'**
  String get analysisSeeClauses;

  /// No description provided for @analysisSelectCalendar.
  ///
  /// In en, this message translates to:
  /// **'Select Date from Calendar'**
  String get analysisSelectCalendar;

  /// No description provided for @analysisSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date *'**
  String get analysisSelectDate;

  /// No description provided for @analysisSelectPolicies.
  ///
  /// In en, this message translates to:
  /// **'Select policies'**
  String get analysisSelectPolicies;

  /// No description provided for @analysisSelectPrescription.
  ///
  /// In en, this message translates to:
  /// **'Select prescription'**
  String get analysisSelectPrescription;

  /// No description provided for @analysisSelfEntered.
  ///
  /// In en, this message translates to:
  /// **'Self-entered'**
  String get analysisSelfEntered;

  /// No description provided for @analysisShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get analysisShare;

  /// No description provided for @analysisShareAssessedItems.
  ///
  /// In en, this message translates to:
  /// **'Share of assessed items that are covered'**
  String get analysisShareAssessedItems;

  /// No description provided for @analysisShareCheck.
  ///
  /// In en, this message translates to:
  /// **'Share check'**
  String get analysisShareCheck;

  /// No description provided for @analysisShareEstimatedBill.
  ///
  /// In en, this message translates to:
  /// **'Share of the estimated bill the insurer may pay'**
  String get analysisShareEstimatedBill;

  /// No description provided for @analysisSharingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is unavailable.'**
  String get analysisSharingUnavailable;

  /// No description provided for @analysisShowingSavedCheck.
  ///
  /// In en, this message translates to:
  /// **'Showing saved check details.'**
  String get analysisShowingSavedCheck;

  /// No description provided for @analysisShowingSavedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Showing saved documents. Try refreshing when you reconnect.'**
  String get analysisShowingSavedDocuments;

  /// No description provided for @analysisSpecifyDetails.
  ///
  /// In en, this message translates to:
  /// **'Please specify details...'**
  String get analysisSpecifyDetails;

  /// No description provided for @analysisStartCheck.
  ///
  /// In en, this message translates to:
  /// **'Start a check'**
  String get analysisStartCheck;

  /// No description provided for @analysisStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start this check. Please try again.'**
  String get analysisStartFailed;

  /// No description provided for @analysisStartNewCheck.
  ///
  /// In en, this message translates to:
  /// **'Start a new check'**
  String get analysisStartNewCheck;

  /// No description provided for @analysisStartWithDocuments.
  ///
  /// In en, this message translates to:
  /// **'Please start a new analysis and add your prescription and policy.'**
  String get analysisStartWithDocuments;

  /// No description provided for @analysisStartingCheck.
  ///
  /// In en, this message translates to:
  /// **'Starting check…'**
  String get analysisStartingCheck;

  /// No description provided for @analysisStatusReason.
  ///
  /// In en, this message translates to:
  /// **'Status Reason'**
  String get analysisStatusReason;

  /// No description provided for @analysisStop.
  ///
  /// In en, this message translates to:
  /// **'Stop analysis'**
  String get analysisStop;

  /// No description provided for @analysisStopExplanation.
  ///
  /// In en, this message translates to:
  /// **'The report will be discarded. Your policy and prescription documents will stay saved.'**
  String get analysisStopExplanation;

  /// No description provided for @analysisStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the analysis stopped. Try again.'**
  String get analysisStopFailed;

  /// No description provided for @analysisStopQuestion.
  ///
  /// In en, this message translates to:
  /// **'Stop the analysis?'**
  String get analysisStopQuestion;

  /// No description provided for @analysisStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping the analysis…'**
  String get analysisStopping;

  /// No description provided for @analysisSubmitAnswers.
  ///
  /// In en, this message translates to:
  /// **'Submit Answers'**
  String get analysisSubmitAnswers;

  /// No description provided for @analysisSumInsured.
  ///
  /// In en, this message translates to:
  /// **'Sum Insured'**
  String get analysisSumInsured;

  /// No description provided for @analysisSystemReference.
  ///
  /// In en, this message translates to:
  /// **'This is a system-generated reference. It does not guarantee approval. Final decisions rest with your insurance provider.'**
  String get analysisSystemReference;

  /// No description provided for @analysisTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get analysisTermsOfUse;

  /// No description provided for @analysisThisPolicySaved.
  ///
  /// In en, this message translates to:
  /// **'This policy is already saved.'**
  String get analysisThisPolicySaved;

  /// No description provided for @analysisTreatmentDocument.
  ///
  /// In en, this message translates to:
  /// **'Treatment document'**
  String get analysisTreatmentDocument;

  /// No description provided for @analysisTreatmentImage.
  ///
  /// In en, this message translates to:
  /// **'Treatment document image'**
  String get analysisTreatmentImage;

  /// No description provided for @analysisTreatmentItem.
  ///
  /// In en, this message translates to:
  /// **'Treatment item'**
  String get analysisTreatmentItem;

  /// No description provided for @analysisTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get analysisTryAgain;

  /// No description provided for @analysisTypeAnswer.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get analysisTypeAnswer;

  /// No description provided for @analysisTypeIn.
  ///
  /// In en, this message translates to:
  /// **'Type it in'**
  String get analysisTypeIn;

  /// No description provided for @analysisTypeTreatment.
  ///
  /// In en, this message translates to:
  /// **'No document? Describe the treatment'**
  String get analysisTypeTreatment;

  /// No description provided for @analysisTypedPrescriptionIssue.
  ///
  /// In en, this message translates to:
  /// **'Self-Entered Prescription Issue'**
  String get analysisTypedPrescriptionIssue;

  /// No description provided for @analysisUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong during the analysis.'**
  String get analysisUnexpectedError;

  /// No description provided for @analysisUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this document. Try a clearer photo.'**
  String get analysisUnreadable;

  /// No description provided for @analysisUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get analysisUploadFile;

  /// No description provided for @analysisUploadedPolicyIssue.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Policy Issue'**
  String get analysisUploadedPolicyIssue;

  /// No description provided for @analysisUploadedPrescriptionIssue.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Prescription Issue'**
  String get analysisUploadedPrescriptionIssue;

  /// No description provided for @analysisUseCamera.
  ///
  /// In en, this message translates to:
  /// **'Use the camera'**
  String get analysisUseCamera;

  /// No description provided for @analysisUseSaved.
  ///
  /// In en, this message translates to:
  /// **'Use saved'**
  String get analysisUseSaved;

  /// No description provided for @analysisUseSavedPolicy.
  ///
  /// In en, this message translates to:
  /// **'Use saved policy'**
  String get analysisUseSavedPolicy;

  /// No description provided for @analysisValidatingDocuments.
  ///
  /// In en, this message translates to:
  /// **'Validating Documents'**
  String get analysisValidatingDocuments;

  /// No description provided for @analysisValidatingExtracted.
  ///
  /// In en, this message translates to:
  /// **'Validating Extracted Data'**
  String get analysisValidatingExtracted;

  /// No description provided for @analysisValidationReasons.
  ///
  /// In en, this message translates to:
  /// **'Validation Failure Reasons'**
  String get analysisValidationReasons;

  /// No description provided for @analysisVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get analysisVerify;

  /// No description provided for @analysisViewCoverageReport.
  ///
  /// In en, this message translates to:
  /// **'View coverage report'**
  String get analysisViewCoverageReport;

  /// No description provided for @analysisViewDocument.
  ///
  /// In en, this message translates to:
  /// **'View document'**
  String get analysisViewDocument;

  /// No description provided for @analysisViewProgress.
  ///
  /// In en, this message translates to:
  /// **'View progress'**
  String get analysisViewProgress;

  /// No description provided for @analysisViewReport.
  ///
  /// In en, this message translates to:
  /// **'View report'**
  String get analysisViewReport;

  /// No description provided for @analysisWaitingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your answer'**
  String get analysisWaitingAnswer;

  /// No description provided for @analysisWaitingStarts.
  ///
  /// In en, this message translates to:
  /// **'Waiting periods count from this date'**
  String get analysisWaitingStarts;

  /// No description provided for @analysisWhatWasChecked.
  ///
  /// In en, this message translates to:
  /// **'What was checked'**
  String get analysisWhatWasChecked;

  /// No description provided for @analysisWhyResult.
  ///
  /// In en, this message translates to:
  /// **'Why this result'**
  String get analysisWhyResult;

  /// No description provided for @analysisWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get analysisWorking;

  /// No description provided for @analysisYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get analysisYes;

  /// No description provided for @analysisYesNo.
  ///
  /// In en, this message translates to:
  /// **'Yes / No'**
  String get analysisYesNo;

  /// No description provided for @analysisStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String analysisStep(int step, int total);

  /// No description provided for @analysisPolicyIndex.
  ///
  /// In en, this message translates to:
  /// **'Policy {number}'**
  String analysisPolicyIndex(int number);

  /// No description provided for @analysisPolicyOf.
  ///
  /// In en, this message translates to:
  /// **'Policy {number} of {total}'**
  String analysisPolicyOf(int number, int total);

  /// No description provided for @analysisAskedPolicy.
  ///
  /// In en, this message translates to:
  /// **'Asked about {policy}'**
  String analysisAskedPolicy(String policy);

  /// No description provided for @analysisQuestionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String analysisQuestionNumber(int number);

  /// No description provided for @analysisNextQuestions.
  ///
  /// In en, this message translates to:
  /// **'Next: {policies} {count, plural, one{also has a question.} other{also have questions.}}'**
  String analysisNextQuestions(String policies, int count);

  /// No description provided for @analysisStepsFinished.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} steps done · {completed} of {count, plural, one{1 policy} other{{count} policies}} finished'**
  String analysisStepsFinished(int done, int total, int completed, int count);

  /// No description provided for @analysisAgainstPolicies.
  ///
  /// In en, this message translates to:
  /// **'Analyzed against {count, plural, one{1 policy} other{{count} policies}}'**
  String analysisAgainstPolicies(int count);

  /// No description provided for @analysisPickLimit.
  ///
  /// In en, this message translates to:
  /// **'Pick up to {count} to see which covers more.'**
  String analysisPickLimit(int count);

  /// No description provided for @analysisSavedCount.
  ///
  /// In en, this message translates to:
  /// **'Saved · {count}'**
  String analysisSavedCount(int count);

  /// No description provided for @analysisCheckPolicies.
  ///
  /// In en, this message translates to:
  /// **'Check {count, plural, one{1 policy} other{{count} policies}}'**
  String analysisCheckPolicies(int count);

  /// No description provided for @analysisCheckedPolicies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 policy checked} other{{count} policies checked}}'**
  String analysisCheckedPolicies(int count);

  /// No description provided for @analysisPolicyFileDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A policy from “{filename}” is already saved.'**
  String analysisPolicyFileDuplicate(String filename);

  /// No description provided for @analysisPrescriptionFileDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A prescription from “{filename}” is already saved.'**
  String analysisPrescriptionFileDuplicate(String filename);

  /// No description provided for @analysisPolicyNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'{name} is already in your saved policies.'**
  String analysisPolicyNameDuplicate(String name);

  /// No description provided for @analysisForPatient.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String analysisForPatient(String name);

  /// No description provided for @analysisCoversTreatment.
  ///
  /// In en, this message translates to:
  /// **'{name} covers this treatment.'**
  String analysisCoversTreatment(String name);

  /// No description provided for @analysisCoversPartTreatment.
  ///
  /// In en, this message translates to:
  /// **'{name} covers part of this treatment.'**
  String analysisCoversPartTreatment(String name);

  /// No description provided for @analysisDoesNotCoverTreatment.
  ///
  /// In en, this message translates to:
  /// **'{name} does not cover this treatment.'**
  String analysisDoesNotCoverTreatment(String name);

  /// No description provided for @analysisSeeClauseCount.
  ///
  /// In en, this message translates to:
  /// **'See policy clauses ({count})'**
  String analysisSeeClauseCount(int count);

  /// No description provided for @analysisManualReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item needs manual review before coverage can be determined.} other{{count} items need manual review before coverage can be determined.}}'**
  String analysisManualReviewCount(int count);

  /// No description provided for @analysisBasedOnItems.
  ///
  /// In en, this message translates to:
  /// **'Based on {count, plural, one{1 prescribed item} other{{count} prescribed items}} assessed against your policy.'**
  String analysisBasedOnItems(int count);

  /// No description provided for @analysisItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item} other{{count} items}}'**
  String analysisItemCount(int count);

  /// No description provided for @analysisItemCountHeadline.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 Item} other{{count} Items}}'**
  String analysisItemCountHeadline(int count);

  /// No description provided for @analysisCompletedIn.
  ///
  /// In en, this message translates to:
  /// **'Analysis completed in {seconds} s'**
  String analysisCompletedIn(String seconds);

  /// No description provided for @analysisEstimatedCostValue.
  ///
  /// In en, this message translates to:
  /// **'Est. cost {cost}'**
  String analysisEstimatedCostValue(String cost);

  /// No description provided for @analysisChartCategory.
  ///
  /// In en, this message translates to:
  /// **'{label}: {percentage}% ({count, plural, one{1 item} other{{count} items}})'**
  String analysisChartCategory(String label, int percentage, int count);

  /// No description provided for @analysisContinuityEarliest.
  ///
  /// In en, this message translates to:
  /// **'Not established (earliest documented: {date})'**
  String analysisContinuityEarliest(String date);

  /// No description provided for @analysisClaimFrom.
  ///
  /// In en, this message translates to:
  /// **'From {source}'**
  String analysisClaimFrom(String source);

  /// No description provided for @analysisBeforeDate.
  ///
  /// In en, this message translates to:
  /// **'Before {date}'**
  String analysisBeforeDate(String date);

  /// No description provided for @analysisGapDateRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to} ({days, plural, one{1 day} other{{days} days}})'**
  String analysisGapDateRange(String from, String to, int days);

  /// No description provided for @analysisOtherReportLanguage.
  ///
  /// In en, this message translates to:
  /// **'This report was generated in {language}.'**
  String analysisOtherReportLanguage(String language);

  /// No description provided for @analysisOtherQuestionLanguage.
  ///
  /// In en, this message translates to:
  /// **'These questions were generated in {language}.'**
  String analysisOtherQuestionLanguage(String language);

  /// No description provided for @analysisNotificationPolicies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{ across 1 policy} other{ across {count} policies}}'**
  String analysisNotificationPolicies(int count);

  /// No description provided for @analysisNotificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Your Policy Pal analysis for {subject}{policies} is complete. Tap to view.'**
  String analysisNotificationComplete(String subject, String policies);

  /// No description provided for @analysisNotificationReview.
  ///
  /// In en, this message translates to:
  /// **'Your Policy Pal analysis for {subject}{policies} is ready to review. Tap to view.'**
  String analysisNotificationReview(String subject, String policies);

  /// No description provided for @analysisPrescriptionDescription.
  ///
  /// In en, this message translates to:
  /// **'A prescription, doctor\'s advice or hospital estimate.'**
  String get analysisPrescriptionDescription;

  /// No description provided for @analysisNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'ANALYSIS NOT COMPLETED'**
  String get analysisNotCompleted;

  /// No description provided for @analysisOverallResult.
  ///
  /// In en, this message translates to:
  /// **'OVERALL COVERAGE RESULT'**
  String get analysisOverallResult;

  /// No description provided for @analysisNoItemDetails.
  ///
  /// In en, this message translates to:
  /// **'No further details were provided for this item.'**
  String get analysisNoItemDetails;

  /// No description provided for @analysisTranslatedWording.
  ///
  /// In en, this message translates to:
  /// **'Translated policy wording'**
  String get analysisTranslatedWording;

  /// No description provided for @analysisViewOriginalWording.
  ///
  /// In en, this message translates to:
  /// **'View original policy wording'**
  String get analysisViewOriginalWording;

  /// No description provided for @analysisTranslationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Policy wording is unavailable in the selected language.'**
  String get analysisTranslationUnavailable;

  /// No description provided for @analysisEnglishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get analysisEnglishLanguage;

  /// No description provided for @analysisTamilLanguage.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get analysisTamilLanguage;

  /// No description provided for @analysisStatusFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get analysisStatusFinished;

  /// No description provided for @analysisStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to start'**
  String get analysisStatusWaiting;

  /// No description provided for @analysisStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get analysisStatusQueued;

  /// No description provided for @analysisStatusAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing'**
  String get analysisStatusAnalyzing;

  /// No description provided for @analysisStatusReview.
  ///
  /// In en, this message translates to:
  /// **'Manual review'**
  String get analysisStatusReview;

  /// No description provided for @analysisStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get analysisStatusFailed;

  /// No description provided for @analysisClauseExcludes.
  ///
  /// In en, this message translates to:
  /// **'Excludes'**
  String get analysisClauseExcludes;

  /// No description provided for @analysisClauseWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting Period'**
  String get analysisClauseWaiting;

  /// No description provided for @analysisClauseCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get analysisClauseCondition;

  /// No description provided for @analysisClauseLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get analysisClauseLimit;

  /// No description provided for @analysisClauseCovers.
  ///
  /// In en, this message translates to:
  /// **'Covers'**
  String get analysisClauseCovers;

  /// No description provided for @analysisClauseOther.
  ///
  /// In en, this message translates to:
  /// **'Policy term'**
  String get analysisClauseOther;

  /// No description provided for @analysisNotificationPrescription.
  ///
  /// In en, this message translates to:
  /// **'your prescription'**
  String get analysisNotificationPrescription;

  /// No description provided for @analysisNotificationOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Policy Pal to continue.'**
  String get analysisNotificationOpen;

  /// No description provided for @analysisNotificationNeedsInput.
  ///
  /// In en, this message translates to:
  /// **'Your check needs input'**
  String get analysisNotificationNeedsInput;

  /// No description provided for @analysisNotificationReady.
  ///
  /// In en, this message translates to:
  /// **'Your check is ready'**
  String get analysisNotificationReady;

  /// No description provided for @analysisNotificationChannel.
  ///
  /// In en, this message translates to:
  /// **'Check updates'**
  String get analysisNotificationChannel;

  /// No description provided for @analysisNoAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'No additional details.'**
  String get analysisNoAdditionalDetails;

  /// No description provided for @analysisPdfOrImage.
  ///
  /// In en, this message translates to:
  /// **'PDF or image'**
  String get analysisPdfOrImage;

  /// No description provided for @analysisCouldNotFinishAnalysis.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t complete the analysis'**
  String get analysisCouldNotFinishAnalysis;

  /// No description provided for @analysisContinuityVerified.
  ///
  /// In en, this message translates to:
  /// **'Continuous coverage verified'**
  String get analysisContinuityVerified;

  /// No description provided for @analysisContinuityGap.
  ///
  /// In en, this message translates to:
  /// **'Coverage gap detected'**
  String get analysisContinuityGap;

  /// No description provided for @analysisContinuityConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflicting policy information'**
  String get analysisContinuityConflict;

  /// No description provided for @analysisContinuityOutside.
  ///
  /// In en, this message translates to:
  /// **'Claim date outside the policy period'**
  String get analysisContinuityOutside;

  /// No description provided for @policyPal.
  ///
  /// In en, this message translates to:
  /// **'Policy Pal'**
  String get policyPal;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'This section could not be displayed. Please go back and try again.'**
  String get startupErrorBody;

  /// No description provided for @authGoogleError.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with Google. Try again or use Email OTP.'**
  String get authGoogleError;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get authEnterEmail;

  /// No description provided for @authEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get authEnterValidEmail;

  /// No description provided for @authSendOtpError.
  ///
  /// In en, this message translates to:
  /// **'Could not send OTP. Please try again.'**
  String get authSendOtpError;

  /// No description provided for @authSendCodeError.
  ///
  /// In en, this message translates to:
  /// **'Could not send a verification code. Please try again.'**
  String get authSendCodeError;

  /// No description provided for @authSignInError.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Please try again.'**
  String get authSignInError;

  /// No description provided for @authCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authCheckEmail;

  /// No description provided for @authVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerify;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogin;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendCode;

  /// No description provided for @authNewUser.
  ///
  /// In en, this message translates to:
  /// **'New to Policy Pal? '**
  String get authNewUser;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email. We\'ll send you a code to log in.'**
  String get authLoginDescription;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueGoogle;

  /// No description provided for @authSignInUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is temporarily unavailable. Please try again later.'**
  String get authSignInUnavailable;

  /// No description provided for @authSplashTagline.
  ///
  /// In en, this message translates to:
  /// **'Know what your policy covers'**
  String get authSplashTagline;

  /// No description provided for @authEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get authEnterName;

  /// No description provided for @authRequestError.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the request. Please try again.'**
  String get authRequestError;

  /// No description provided for @authExistingAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authExistingAccount;

  /// No description provided for @authRegisterDescription.
  ///
  /// In en, this message translates to:
  /// **'Save your policies and prescriptions, and check your cover anytime.'**
  String get authRegisterDescription;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get authLegalPrefix;

  /// No description provided for @authTermsShort.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get authTermsShort;

  /// No description provided for @authLegalAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get authLegalAnd;

  /// No description provided for @authPrivacyShort.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy.'**
  String get authPrivacyShort;

  /// No description provided for @authYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authYourName;

  /// No description provided for @authChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get authChangeEmail;

  /// No description provided for @authVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get authVerificationCode;

  /// No description provided for @authResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authResendCode;

  /// No description provided for @authTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get authTermsTitle;

  /// No description provided for @authTermsFirst.
  ///
  /// In en, this message translates to:
  /// **'Only upload documents that belong to you or that you have permission to use.'**
  String get authTermsFirst;

  /// No description provided for @authTermsSecond.
  ///
  /// In en, this message translates to:
  /// **'Coverage checks are for reference. Policy Pal does not submit claims. Your insurer makes the final decision.'**
  String get authTermsSecond;

  /// No description provided for @authPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get authPrivacyTitle;

  /// No description provided for @authPrivacyFirst.
  ///
  /// In en, this message translates to:
  /// **'Policy Pal stores the documents you upload and processes them to evaluate coverage.'**
  String get authPrivacyFirst;

  /// No description provided for @authPrivacySecond.
  ///
  /// In en, this message translates to:
  /// **'You confirm consent before adding a document.'**
  String get authPrivacySecond;

  /// No description provided for @accountEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get accountEditName;

  /// No description provided for @accountLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your account.'**
  String get accountLoadError;

  /// No description provided for @accountSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountSave;

  /// No description provided for @accountEmailReadOnly.
  ///
  /// In en, this message translates to:
  /// **'You log in with this email, so it can\'t be changed here.'**
  String get accountEmailReadOnly;

  /// No description provided for @accountSaveNameError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your name. Try again.'**
  String get accountSaveNameError;

  /// No description provided for @accountOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline.'**
  String get accountOffline;

  /// No description provided for @accountOfflineCached.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing saved account details.'**
  String get accountOfflineCached;

  /// No description provided for @accountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account details are unavailable.'**
  String get accountUnavailable;

  /// No description provided for @accountPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get accountPreferences;

  /// No description provided for @accountAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// No description provided for @accountHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get accountHelp;

  /// No description provided for @accountHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help and support'**
  String get accountHelpSupport;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accountLogout;

  /// No description provided for @accountLogoutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get accountLogoutQuestion;

  /// No description provided for @accountLogoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Your documents and checks stay saved. Log in with your email to see them again.'**
  String get accountLogoutDescription;

  /// No description provided for @accountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountCancel;

  /// No description provided for @accountMatchDevice.
  ///
  /// In en, this message translates to:
  /// **'Match your phone\'s setting'**
  String get accountMatchDevice;

  /// No description provided for @accountThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get accountThemeSystem;

  /// No description provided for @accountThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get accountThemeLight;

  /// No description provided for @accountThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get accountThemeDark;

  /// No description provided for @accountSupportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Support contact is unavailable.'**
  String get accountSupportUnavailable;

  /// No description provided for @accountSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support email'**
  String get accountSupportEmail;

  /// No description provided for @accountSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send email'**
  String get accountSendEmail;

  /// No description provided for @accountCopyEmail.
  ///
  /// In en, this message translates to:
  /// **'Copy email'**
  String get accountCopyEmail;

  /// No description provided for @accountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// No description provided for @accountNotificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications in your phone settings to receive alerts.'**
  String get accountNotificationPermission;

  /// No description provided for @accountNotificationSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your notification setting.'**
  String get accountNotificationSaveError;

  /// No description provided for @accountNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotifications;

  /// No description provided for @accountGoogleLinked.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in linked.'**
  String get accountGoogleLinked;

  /// No description provided for @accountGoogleLinkError.
  ///
  /// In en, this message translates to:
  /// **'Could not link Google sign-in.'**
  String get accountGoogleLinkError;

  /// No description provided for @accountVerifyNewEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify New Email Address'**
  String get accountVerifyNewEmail;

  /// No description provided for @accountVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get accountVerifying;

  /// No description provided for @accountVerifySave.
  ///
  /// In en, this message translates to:
  /// **'Verify & Save'**
  String get accountVerifySave;

  /// No description provided for @accountEnterVerification.
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code.'**
  String get accountEnterVerification;

  /// No description provided for @accountEmailUpdated.
  ///
  /// In en, this message translates to:
  /// **'Email updated successfully!'**
  String get accountEmailUpdated;

  /// No description provided for @accountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get accountEditProfile;

  /// No description provided for @accountPersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get accountPersonalInfo;

  /// No description provided for @accountPersonalInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Used on your account and analysis reports.'**
  String get accountPersonalInfoDescription;

  /// No description provided for @accountFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get accountFullName;

  /// No description provided for @accountFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get accountFullNameHint;

  /// No description provided for @accountEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get accountEmailAddress;

  /// No description provided for @accountEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get accountEmailHint;

  /// No description provided for @accountSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get accountSaving;

  /// No description provided for @accountSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get accountSaveChanges;

  /// No description provided for @accountEmptyName.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get accountEmptyName;

  /// No description provided for @accountValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get accountValidEmail;

  /// No description provided for @accountUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get accountUpdated;

  /// No description provided for @accountGoogleIsLinked.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is linked.'**
  String get accountGoogleIsLinked;

  /// No description provided for @accountGoogleLinking.
  ///
  /// In en, this message translates to:
  /// **'Linking Google…'**
  String get accountGoogleLinking;

  /// No description provided for @accountLinkGoogle.
  ///
  /// In en, this message translates to:
  /// **'Link Google sign-in'**
  String get accountLinkGoogle;

  /// No description provided for @accountLoginMethods.
  ///
  /// In en, this message translates to:
  /// **'Login methods'**
  String get accountLoginMethods;

  /// No description provided for @accountVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get accountVerified;

  /// No description provided for @authEnterOtp.
  ///
  /// In en, this message translates to:
  /// **'Please enter the OTP.'**
  String get authEnterOtp;

  /// No description provided for @accountEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully.'**
  String get accountEmailVerified;

  /// No description provided for @authVerifyError.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try again.'**
  String get authVerifyError;

  /// No description provided for @accountVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Email Address'**
  String get accountVerifyEmail;

  /// No description provided for @authOtp.
  ///
  /// In en, this message translates to:
  /// **'OTP'**
  String get authOtp;

  /// No description provided for @authResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get authResendOtp;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @accountLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get accountLanguageEnglish;

  /// No description provided for @accountLanguageTamil.
  ///
  /// In en, this message translates to:
  /// **'தமிழ்'**
  String get accountLanguageTamil;

  /// No description provided for @accountLanguageUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your language. Try again.'**
  String get accountLanguageUpdateError;

  /// No description provided for @accountEmailLoginEnabled.
  ///
  /// In en, this message translates to:
  /// **'Email OTP login enabled'**
  String get accountEmailLoginEnabled;

  /// No description provided for @accountEmailLoginVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify to enable Email OTP login'**
  String get accountEmailLoginVerify;

  /// No description provided for @accountProfileUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile. Try again.'**
  String get accountProfileUpdateError;

  /// No description provided for @accountEmailSendError.
  ///
  /// In en, this message translates to:
  /// **'Could not send verification code. Try again.'**
  String get accountEmailSendError;

  /// No description provided for @authInvalidOtp.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t right. Check it, or get a new one.'**
  String get authInvalidOtp;

  /// No description provided for @authCouldNotVerify.
  ///
  /// In en, this message translates to:
  /// **'Could not verify the code. Try again.'**
  String get authCouldNotVerify;

  /// No description provided for @authCheckDetails.
  ///
  /// In en, this message translates to:
  /// **'Please check the details and try again.'**
  String get authCheckDetails;

  /// No description provided for @authNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection. Please check your internet and try again.'**
  String get authNoConnection;

  /// No description provided for @authEmailRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email address is already registered. Please login.'**
  String get authEmailRegistered;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email address. Please register first.'**
  String get authNoAccount;

  /// No description provided for @authOtpUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The email verification service is temporarily unavailable.'**
  String get authOtpUnavailable;

  /// No description provided for @authTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get authTooManyRequests;

  /// No description provided for @authUndeliverable.
  ///
  /// In en, this message translates to:
  /// **'This email address cannot receive email. Please check it.'**
  String get authUndeliverable;

  /// No description provided for @authGoogleAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This Google account is already linked.'**
  String get authGoogleAlreadyLinked;

  /// No description provided for @authCodeEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter the {length}-digit code we sent to'**
  String authCodeEnter(int length);

  /// No description provided for @authCodeResendTimer.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {timer}'**
  String authCodeResendTimer(String timer);

  /// No description provided for @accountVersion.
  ///
  /// In en, this message translates to:
  /// **'Policy Pal · Version {version}'**
  String accountVersion(String version);

  /// No description provided for @accountOtpSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification code to {email}. Please enter it below to confirm your new email.'**
  String accountOtpSent(String email);

  /// No description provided for @accountOtpSending.
  ///
  /// In en, this message translates to:
  /// **'Sending a code to {email}...'**
  String accountOtpSending(String email);

  /// No description provided for @accountOtpResendTimer.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP in {seconds}s'**
  String accountOtpResendTimer(int seconds);

  /// No description provided for @authOtpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to {email}'**
  String authOtpSent(String email);

  /// No description provided for @accountSupportSubject.
  ///
  /// In en, this message translates to:
  /// **'Policy Pal Assistance'**
  String get accountSupportSubject;

  /// No description provided for @sharedHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get sharedHome;

  /// No description provided for @sharedHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get sharedHistory;

  /// No description provided for @sharedNewCheck.
  ///
  /// In en, this message translates to:
  /// **'New check'**
  String get sharedNewCheck;

  /// No description provided for @sharedSelectPrescription.
  ///
  /// In en, this message translates to:
  /// **'Select prescription'**
  String get sharedSelectPrescription;

  /// No description provided for @sharedSelectPolicy.
  ///
  /// In en, this message translates to:
  /// **'Select policy'**
  String get sharedSelectPolicy;

  /// No description provided for @sharedViewClaimCoverage.
  ///
  /// In en, this message translates to:
  /// **'View claim coverage'**
  String get sharedViewClaimCoverage;

  /// No description provided for @sharedProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get sharedProfile;

  /// No description provided for @sharedBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get sharedBest;

  /// No description provided for @sharedSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get sharedSeeAll;

  /// No description provided for @sharedRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sharedRetry;

  /// No description provided for @sharedCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get sharedCancel;

  /// No description provided for @sharedSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get sharedSessionExpired;

  /// No description provided for @sharedSessionExpiredExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your login session has expired. Please sign in again to continue.'**
  String get sharedSessionExpiredExplanation;

  /// No description provided for @sharedOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get sharedOk;

  /// No description provided for @sharedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sharedTryAgain;

  /// No description provided for @sharedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this information. Please check your connection and try again.'**
  String get sharedLoadFailed;

  /// No description provided for @sharedSponsored.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get sharedSponsored;

  /// No description provided for @sharedHideAdvertisement.
  ///
  /// In en, this message translates to:
  /// **'Hide advertisement'**
  String get sharedHideAdvertisement;

  /// No description provided for @sharedCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Can’t connect to Policy Pal'**
  String get sharedCannotConnect;

  /// No description provided for @sharedRecentChecks.
  ///
  /// In en, this message translates to:
  /// **'Recent checks'**
  String get sharedRecentChecks;

  /// No description provided for @sharedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get sharedDocuments;

  /// No description provided for @sharedKnowYourCover.
  ///
  /// In en, this message translates to:
  /// **'Know your cover before the bill'**
  String get sharedKnowYourCover;

  /// No description provided for @sharedFirstCheck.
  ///
  /// In en, this message translates to:
  /// **'Start your first check'**
  String get sharedFirstCheck;

  /// No description provided for @sharedHi.
  ///
  /// In en, this message translates to:
  /// **'Hi'**
  String get sharedHi;

  /// No description provided for @sharedResumeDraft.
  ///
  /// In en, this message translates to:
  /// **'Continue your draft check'**
  String get sharedResumeDraft;

  /// No description provided for @sharedResumeCheck.
  ///
  /// In en, this message translates to:
  /// **'Resume your last check'**
  String get sharedResumeCheck;

  /// No description provided for @sharedPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get sharedPrescriptions;

  /// No description provided for @sharedPolicies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get sharedPolicies;

  /// No description provided for @sharedViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get sharedViewAll;

  /// No description provided for @sharedNextCheck.
  ///
  /// In en, this message translates to:
  /// **'Next check'**
  String get sharedNextCheck;

  /// No description provided for @sharedPreviousCheck.
  ///
  /// In en, this message translates to:
  /// **'Previous check'**
  String get sharedPreviousCheck;

  /// No description provided for @sharedViewDocument.
  ///
  /// In en, this message translates to:
  /// **'View document'**
  String get sharedViewDocument;

  /// No description provided for @sharedAddPrescription.
  ///
  /// In en, this message translates to:
  /// **'Add prescription'**
  String get sharedAddPrescription;

  /// No description provided for @sharedOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline.'**
  String get sharedOffline;

  /// No description provided for @sharedAddPolicyWithCheck.
  ///
  /// In en, this message translates to:
  /// **'Add policies when you start a check.'**
  String get sharedAddPolicyWithCheck;

  /// No description provided for @sharedLongPressDelete.
  ///
  /// In en, this message translates to:
  /// **'Long-press to select and delete.'**
  String get sharedLongPressDelete;

  /// No description provided for @sharedRetryLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Retry loading more'**
  String get sharedRetryLoadingMore;

  /// No description provided for @sharedExitSelection.
  ///
  /// In en, this message translates to:
  /// **'Exit selection'**
  String get sharedExitSelection;

  /// No description provided for @sharedSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get sharedSelectAll;

  /// No description provided for @sharedSelectAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t select all items. Try again.'**
  String get sharedSelectAllFailed;

  /// No description provided for @sharedDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sharedDelete;

  /// No description provided for @sharedConfirmDeleteDocument.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone. Checks that used them stay in History.'**
  String get sharedConfirmDeleteDocument;

  /// No description provided for @sharedConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get sharedConfirmDelete;

  /// No description provided for @sharedDeleteUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm deletion. Check the list and try again.'**
  String get sharedDeleteUnconfirmed;

  /// No description provided for @sharedLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get sharedLoading;

  /// No description provided for @sharedMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get sharedMembers;

  /// No description provided for @sharedNoPolicyDetails.
  ///
  /// In en, this message translates to:
  /// **'No extracted policy details yet.'**
  String get sharedNoPolicyDetails;

  /// No description provided for @sharedItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get sharedItems;

  /// No description provided for @sharedNoPrescriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'No extracted prescription details yet.'**
  String get sharedNoPrescriptionDetails;

  /// No description provided for @sharedManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Type it in'**
  String get sharedManualEntry;

  /// No description provided for @sharedEnterTreatment.
  ///
  /// In en, this message translates to:
  /// **'Write the illness, symptoms, tests or surgery the doctor advised. A few words is enough.'**
  String get sharedEnterTreatment;

  /// No description provided for @sharedTreatment.
  ///
  /// In en, this message translates to:
  /// **'Treatment'**
  String get sharedTreatment;

  /// No description provided for @sharedCheckAsAdmittedToday.
  ///
  /// In en, this message translates to:
  /// **'We\'ll check it as if you\'re admitted to hospital today.'**
  String get sharedCheckAsAdmittedToday;

  /// No description provided for @sharedSavePrescription.
  ///
  /// In en, this message translates to:
  /// **'Save prescription'**
  String get sharedSavePrescription;

  /// No description provided for @sharedSavePrescriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your prescription. Try again.'**
  String get sharedSavePrescriptionFailed;

  /// No description provided for @sharedBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get sharedBack;

  /// No description provided for @sharedLoadingDocument.
  ///
  /// In en, this message translates to:
  /// **'Loading document…'**
  String get sharedLoadingDocument;

  /// No description provided for @sharedUnreadableDocument.
  ///
  /// In en, this message translates to:
  /// **'This file could not be opened. Upload a readable copy of the document.'**
  String get sharedUnreadableDocument;

  /// No description provided for @sharedImageOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this image.'**
  String get sharedImageOpenFailed;

  /// No description provided for @sharedFirstStartDate.
  ///
  /// In en, this message translates to:
  /// **'Date this policy was first taken'**
  String get sharedFirstStartDate;

  /// No description provided for @sharedPolicyStartDate.
  ///
  /// In en, this message translates to:
  /// **'Policy start date'**
  String get sharedPolicyStartDate;

  /// No description provided for @sharedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get sharedConfirm;

  /// No description provided for @sharedTooManyFiles.
  ///
  /// In en, this message translates to:
  /// **'Too many files selected'**
  String get sharedTooManyFiles;

  /// No description provided for @sharedSelectAgain.
  ///
  /// In en, this message translates to:
  /// **'Select again'**
  String get sharedSelectAgain;

  /// No description provided for @sharedPleaseUploadPolicy.
  ///
  /// In en, this message translates to:
  /// **'Please upload at least one policy document.'**
  String get sharedPleaseUploadPolicy;

  /// No description provided for @sharedStillReadingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Still reading your policy. This takes a few seconds.'**
  String get sharedStillReadingPolicy;

  /// No description provided for @sharedConfirmPolicyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the confirmed policy details. Please try again.'**
  String get sharedConfirmPolicyFailed;

  /// No description provided for @sharedUploadPolicy.
  ///
  /// In en, this message translates to:
  /// **'Upload Policy'**
  String get sharedUploadPolicy;

  /// No description provided for @sharedAddInsurancePolicy.
  ///
  /// In en, this message translates to:
  /// **'Add your insurance policy'**
  String get sharedAddInsurancePolicy;

  /// No description provided for @sharedExplainPolicyUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload one or more insurance policy documents. Add several to compare them against the same prescription.'**
  String get sharedExplainPolicyUpload;

  /// No description provided for @sharedReadEachPolicy.
  ///
  /// In en, this message translates to:
  /// **'We read the details from each policy'**
  String get sharedReadEachPolicy;

  /// No description provided for @sharedUploadPdfOrImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload PDF or Image'**
  String get sharedUploadPdfOrImage;

  /// No description provided for @sharedAddAnotherPolicy.
  ///
  /// In en, this message translates to:
  /// **'Tap to add another policy'**
  String get sharedAddAnotherPolicy;

  /// No description provided for @sharedUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get sharedUploading;

  /// No description provided for @sharedAnalyzeCoverage.
  ///
  /// In en, this message translates to:
  /// **'Analyze Coverage'**
  String get sharedAnalyzeCoverage;

  /// No description provided for @sharedRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get sharedRemove;

  /// No description provided for @sharedReadingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Reading your policy details…'**
  String get sharedReadingPolicy;

  /// No description provided for @sharedNewOrRenewed.
  ///
  /// In en, this message translates to:
  /// **'Is this a new policy or a renewed policy?'**
  String get sharedNewOrRenewed;

  /// No description provided for @sharedNewFirstYear.
  ///
  /// In en, this message translates to:
  /// **'New (first year)'**
  String get sharedNewFirstYear;

  /// No description provided for @sharedRenewed.
  ///
  /// In en, this message translates to:
  /// **'Renewed'**
  String get sharedRenewed;

  /// No description provided for @sharedWhenFirstTaken.
  ///
  /// In en, this message translates to:
  /// **'When was this policy first taken?'**
  String get sharedWhenFirstTaken;

  /// No description provided for @sharedFirstDateHint.
  ///
  /// In en, this message translates to:
  /// **'The very first start date of this policy, before any renewals.'**
  String get sharedFirstDateHint;

  /// No description provided for @sharedPolicyDateHint.
  ///
  /// In en, this message translates to:
  /// **'The date this policy started, as shown on your policy document.'**
  String get sharedPolicyDateHint;

  /// No description provided for @sharedSelectFirstDate.
  ///
  /// In en, this message translates to:
  /// **'Select first start date'**
  String get sharedSelectFirstDate;

  /// No description provided for @sharedSelectStartDate.
  ///
  /// In en, this message translates to:
  /// **'Select policy start date'**
  String get sharedSelectStartDate;

  /// No description provided for @sharedContinuousRenewalQuestion.
  ///
  /// In en, this message translates to:
  /// **'Has this policy been renewed every year without a break?'**
  String get sharedContinuousRenewalQuestion;

  /// No description provided for @sharedPortabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Answer Yes if you moved from another insurance company without any gap (portability).'**
  String get sharedPortabilityHint;

  /// No description provided for @sharedYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get sharedYes;

  /// No description provided for @sharedNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get sharedNo;

  /// No description provided for @sharedLooksInvalidPolicy.
  ///
  /// In en, this message translates to:
  /// **'This file does not look like an insurance policy. Check the file, or answer the questions below.'**
  String get sharedLooksInvalidPolicy;

  /// No description provided for @sharedPolicyDetailsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'We could not read the details from this policy. Please answer the questions below.'**
  String get sharedPolicyDetailsUnreadable;

  /// No description provided for @sharedInsurer.
  ///
  /// In en, this message translates to:
  /// **'Insurer'**
  String get sharedInsurer;

  /// No description provided for @sharedPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get sharedPlan;

  /// No description provided for @sharedPolicyNumber.
  ///
  /// In en, this message translates to:
  /// **'Policy number'**
  String get sharedPolicyNumber;

  /// No description provided for @sharedPolicyHolder.
  ///
  /// In en, this message translates to:
  /// **'Policy holder'**
  String get sharedPolicyHolder;

  /// No description provided for @sharedPolicyPeriod.
  ///
  /// In en, this message translates to:
  /// **'Policy period'**
  String get sharedPolicyPeriod;

  /// No description provided for @sharedSumInsured.
  ///
  /// In en, this message translates to:
  /// **'Sum insured'**
  String get sharedSumInsured;

  /// No description provided for @sharedPolicyType.
  ///
  /// In en, this message translates to:
  /// **'Policy type'**
  String get sharedPolicyType;

  /// No description provided for @sharedFirstTakenOn.
  ///
  /// In en, this message translates to:
  /// **'First taken on'**
  String get sharedFirstTakenOn;

  /// No description provided for @sharedStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get sharedStartDate;

  /// No description provided for @sharedRenewedContinuously.
  ///
  /// In en, this message translates to:
  /// **'Renewed without a break'**
  String get sharedRenewedContinuously;

  /// No description provided for @sharedPolicyDetails.
  ///
  /// In en, this message translates to:
  /// **'Details from your policy'**
  String get sharedPolicyDetails;

  /// No description provided for @sharedDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sharedDone;

  /// No description provided for @sharedEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sharedEdit;

  /// No description provided for @sharedMissingPolicyDetails.
  ///
  /// In en, this message translates to:
  /// **'Your policy does not state the following, so please answer:'**
  String get sharedMissingPolicyDetails;

  /// No description provided for @sharedUploadServerError.
  ///
  /// In en, this message translates to:
  /// **'Our servers are experiencing issues processing your upload. Please try again later.'**
  String get sharedUploadServerError;

  /// No description provided for @sharedUploadUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred during upload. Please try again later.'**
  String get sharedUploadUnexpected;

  /// No description provided for @sharedChooseOnePrescriptionMethod.
  ///
  /// In en, this message translates to:
  /// **'Please choose only one prescription input method: either upload a prescription PDF or enter your prescription manually.'**
  String get sharedChooseOnePrescriptionMethod;

  /// No description provided for @sharedProvidePrescription.
  ///
  /// In en, this message translates to:
  /// **'Please upload a prescription PDF or enter your prescription manually.'**
  String get sharedProvidePrescription;

  /// No description provided for @sharedCouldNotSavePrescription.
  ///
  /// In en, this message translates to:
  /// **'Could not save the prescription. Please try again.'**
  String get sharedCouldNotSavePrescription;

  /// No description provided for @sharedExistingPolicyFound.
  ///
  /// In en, this message translates to:
  /// **'Existing Policy Found'**
  String get sharedExistingPolicyFound;

  /// No description provided for @sharedUseSavedPolicy.
  ///
  /// In en, this message translates to:
  /// **'We found existing policies in your account. Would you like to analyze this prescription using one of your saved policies?'**
  String get sharedUseSavedPolicy;

  /// No description provided for @sharedContinueExistingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Continue Existing Policy'**
  String get sharedContinueExistingPolicy;

  /// No description provided for @sharedUploadNewPolicy.
  ///
  /// In en, this message translates to:
  /// **'Upload New Policy'**
  String get sharedUploadNewPolicy;

  /// No description provided for @sharedSelectPolicies.
  ///
  /// In en, this message translates to:
  /// **'Select Policies'**
  String get sharedSelectPolicies;

  /// No description provided for @sharedInsurancePolicy.
  ///
  /// In en, this message translates to:
  /// **'Insurance Policy'**
  String get sharedInsurancePolicy;

  /// No description provided for @sharedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get sharedUnknown;

  /// No description provided for @sharedValidity.
  ///
  /// In en, this message translates to:
  /// **'Validity'**
  String get sharedValidity;

  /// No description provided for @sharedStartDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get sharedStartDateTitle;

  /// No description provided for @sharedExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get sharedExpiry;

  /// No description provided for @sharedHolder.
  ///
  /// In en, this message translates to:
  /// **'Holder'**
  String get sharedHolder;

  /// No description provided for @sharedPolicyNo.
  ///
  /// In en, this message translates to:
  /// **'Policy No'**
  String get sharedPolicyNo;

  /// No description provided for @sharedFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get sharedFile;

  /// No description provided for @sharedAnalyzeWithSelectedPolicy.
  ///
  /// In en, this message translates to:
  /// **'Analyze With Selected Policy'**
  String get sharedAnalyzeWithSelectedPolicy;

  /// No description provided for @sharedAddPrescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Prescription'**
  String get sharedAddPrescriptionTitle;

  /// No description provided for @sharedAddYourPrescription.
  ///
  /// In en, this message translates to:
  /// **'Add your prescription'**
  String get sharedAddYourPrescription;

  /// No description provided for @sharedUploadDoctorDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload your doctor\'s prescription, diagnosis, or medical bills.'**
  String get sharedUploadDoctorDocument;

  /// No description provided for @sharedUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload a document'**
  String get sharedUploadDocument;

  /// No description provided for @sharedUploadMedicalDocuments.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload medical documents'**
  String get sharedUploadMedicalDocuments;

  /// No description provided for @sharedKeepAppOpen.
  ///
  /// In en, this message translates to:
  /// **'Please keep the app open'**
  String get sharedKeepAppOpen;

  /// No description provided for @sharedUploadSucceeded.
  ///
  /// In en, this message translates to:
  /// **'File uploaded successfully'**
  String get sharedUploadSucceeded;

  /// No description provided for @sharedOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get sharedOr;

  /// No description provided for @sharedManualPrescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your prescription manually'**
  String get sharedManualPrescription;

  /// No description provided for @sharedPrescriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Prescription / Diagnosis Details'**
  String get sharedPrescriptionDetails;

  /// No description provided for @sharedClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get sharedClear;

  /// No description provided for @sharedDescribeSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Describe your diagnosis, symptoms, doctor\'s findings, or prescribed treatment...'**
  String get sharedDescribeSymptoms;

  /// No description provided for @sharedReadingPrescription.
  ///
  /// In en, this message translates to:
  /// **'Reading prescription?'**
  String get sharedReadingPrescription;

  /// No description provided for @sharedProcessManualPrescription.
  ///
  /// In en, this message translates to:
  /// **'Process Manual Prescription'**
  String get sharedProcessManualPrescription;

  /// No description provided for @sharedProcessPrescription.
  ///
  /// In en, this message translates to:
  /// **'Process Prescription'**
  String get sharedProcessPrescription;

  /// No description provided for @sharedReplaceFile.
  ///
  /// In en, this message translates to:
  /// **'Replace file'**
  String get sharedReplaceFile;

  /// No description provided for @sharedRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get sharedRemoveFile;

  /// No description provided for @sharedGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String sharedGreeting(String name);

  /// No description provided for @sharedShowingSavedChecks.
  ///
  /// In en, this message translates to:
  /// **'{message} Showing your saved checks.'**
  String sharedShowingSavedChecks(String message);

  /// No description provided for @sharedFileLimit.
  ///
  /// In en, this message translates to:
  /// **'Each file must be {max} MB or smaller.'**
  String sharedFileLimit(int max);

  /// No description provided for @sharedPdfImageLimit.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG, PNG · {max} MB max'**
  String sharedPdfImageLimit(int max);

  /// No description provided for @sharedUploadNamed.
  ///
  /// In en, this message translates to:
  /// **'Uploading {name}…'**
  String sharedUploadNamed(String name);

  /// No description provided for @sharedPickUpToPolicies.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {max} policies'**
  String sharedPickUpToPolicies(int max);

  /// No description provided for @sharedAnalyzeWithPolicies.
  ///
  /// In en, this message translates to:
  /// **'Analyze With {count} Policies'**
  String sharedAnalyzeWithPolicies(int count);

  /// No description provided for @sharedDateRange.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String sharedDateRange(String start, String end);

  /// No description provided for @sharedPolicyFileSelectionLimit.
  ///
  /// In en, this message translates to:
  /// **'You selected {count} files. You can add {remaining} more, up to {max} policies in total.'**
  String sharedPolicyFileSelectionLimit(int count, int remaining, int max);

  /// No description provided for @sharedPolicyPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Select up to {remaining} · max {max} policies · {size} MB each'**
  String sharedPolicyPickerHint(int remaining, int max, int size);

  /// No description provided for @sharedPoliciesAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 policy added} other{{count} policies added}}'**
  String sharedPoliciesAdded(int count);

  /// No description provided for @sharedComparePolicies.
  ///
  /// In en, this message translates to:
  /// **'Compare {count} Policies'**
  String sharedComparePolicies(int count);

  /// No description provided for @sharedUploadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload {name}.'**
  String sharedUploadFileFailed(String name);

  /// No description provided for @sharedProcessFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Our servers could not process {name}. Please try again later.'**
  String sharedProcessFileFailed(String name);

  /// No description provided for @sharedAddFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add {name}. Please try again.'**
  String sharedAddFileFailed(String name);

  /// No description provided for @sharedCoverageGap.
  ///
  /// In en, this message translates to:
  /// **'You have a coverage gap in your policy continuity. So the coverage analysis will check your prescription against this policy from the start date of the uploaded policy document.'**
  String get sharedCoverageGap;

  /// No description provided for @sharedDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get sharedDocument;

  /// No description provided for @sharedSavedPrescription.
  ///
  /// In en, this message translates to:
  /// **'Saved prescription'**
  String get sharedSavedPrescription;

  /// No description provided for @sharedStep.
  ///
  /// In en, this message translates to:
  /// **'Step {label}'**
  String sharedStep(String label);

  /// No description provided for @sharedSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved'**
  String sharedSavedCount(int count);

  /// No description provided for @sharedSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String sharedSelectedCount(int count);

  /// No description provided for @sharedOfflineShowSaved.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing saved {items}.'**
  String sharedOfflineShowSaved(String items);

  /// No description provided for @sharedCouldNotLoadItems.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load {items}.'**
  String sharedCouldNotLoadItems(String items);

  /// No description provided for @sharedDocumentsShownHere.
  ///
  /// In en, this message translates to:
  /// **'{title} you add in a check show up here.'**
  String sharedDocumentsShownHere(String title);

  /// No description provided for @sharedNoFilteredDocuments.
  ///
  /// In en, this message translates to:
  /// **'No {filter} {items}.'**
  String sharedNoFilteredDocuments(String filter, String items);

  /// No description provided for @sharedAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sharedAll;

  /// No description provided for @sharedUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get sharedUploaded;

  /// No description provided for @sharedManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get sharedManual;

  /// No description provided for @sharedRemoveSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} {items}'**
  String sharedRemoveSelected(int count, String items);

  /// No description provided for @sharedConfirmRemoveSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} {items}?'**
  String sharedConfirmRemoveSelected(int count, String items);

  /// No description provided for @sharedDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} {items}.'**
  String sharedDeletedCount(int count, String items);

  /// No description provided for @sharedDeletedPartial.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} of {selected} selected {items}. The list has been refreshed.'**
  String sharedDeletedPartial(int count, int selected, String items);

  /// No description provided for @sharedSorryError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get sharedSorryError;

  /// No description provided for @sharedNetwork.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t reach Policy Pal’s server. Check your internet connection and try again.'**
  String get sharedNetwork;

  /// No description provided for @sharedTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond. Please try again.'**
  String get sharedTimeout;

  /// No description provided for @sharedServerError.
  ///
  /// In en, this message translates to:
  /// **'Policy Pal’s server is having trouble right now. Please try again in a moment.'**
  String get sharedServerError;

  /// No description provided for @sharedSessionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get sharedSessionInvalid;

  /// No description provided for @sharedForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get sharedForbidden;

  /// No description provided for @sharedNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested information could not be found.'**
  String get sharedNotFound;

  /// No description provided for @sharedConflict.
  ///
  /// In en, this message translates to:
  /// **'This action conflicts with an existing record.'**
  String get sharedConflict;

  /// No description provided for @sharedInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Check the information you entered and try again.'**
  String get sharedInvalidRequest;

  /// No description provided for @sharedUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'This file format is not supported.'**
  String get sharedUnsupportedFile;

  /// No description provided for @sharedFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file exceeds the upload size limit.'**
  String get sharedFileTooLarge;

  /// No description provided for @sharedTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a moment and try again.'**
  String get sharedTooManyRequests;

  /// No description provided for @sharedCovered.
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get sharedCovered;

  /// No description provided for @sharedFullyCovered.
  ///
  /// In en, this message translates to:
  /// **'Fully covered'**
  String get sharedFullyCovered;

  /// No description provided for @sharedPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially covered'**
  String get sharedPartial;

  /// No description provided for @sharedNotCovered.
  ///
  /// In en, this message translates to:
  /// **'Not covered'**
  String get sharedNotCovered;

  /// No description provided for @sharedVerification.
  ///
  /// In en, this message translates to:
  /// **'Needs verification'**
  String get sharedVerification;

  /// No description provided for @sharedNeedsInfo.
  ///
  /// In en, this message translates to:
  /// **'Needs info'**
  String get sharedNeedsInfo;

  /// No description provided for @sharedNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get sharedNeedsReview;

  /// No description provided for @sharedInvalidPolicy.
  ///
  /// In en, this message translates to:
  /// **'Invalid policy'**
  String get sharedInvalidPolicy;

  /// No description provided for @sharedInvalidPrescription.
  ///
  /// In en, this message translates to:
  /// **'Not a prescription'**
  String get sharedInvalidPrescription;

  /// No description provided for @sharedInvalidDocument.
  ///
  /// In en, this message translates to:
  /// **'Invalid document'**
  String get sharedInvalidDocument;

  /// No description provided for @sharedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Result not available'**
  String get sharedUnavailable;

  /// No description provided for @sharedChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get sharedChecking;

  /// No description provided for @sharedFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed'**
  String get sharedFailed;

  /// No description provided for @sharedCouldNotCheck.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check'**
  String get sharedCouldNotCheck;

  /// No description provided for @sharedCancelled.
  ///
  /// In en, this message translates to:
  /// **'Check cancelled'**
  String get sharedCancelled;

  /// No description provided for @sharedPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get sharedPending;

  /// No description provided for @sharedCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sharedCompleted;

  /// No description provided for @sharedExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get sharedExpired;

  /// No description provided for @sharedReading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get sharedReading;

  /// No description provided for @sharedCouldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t read'**
  String get sharedCouldNotRead;

  /// No description provided for @sharedStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get sharedStatusUnavailable;

  /// No description provided for @sharedIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get sharedIndividual;

  /// No description provided for @sharedFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get sharedFamily;

  /// No description provided for @sharedFamilyFloater.
  ///
  /// In en, this message translates to:
  /// **'Family floater'**
  String get sharedFamilyFloater;

  /// No description provided for @sharedGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get sharedGroup;

  /// No description provided for @sharedToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sharedToday;

  /// No description provided for @sharedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get sharedYesterday;

  /// No description provided for @sharedPrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get sharedPrescription;

  /// No description provided for @sharedPolicy.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get sharedPolicy;

  /// No description provided for @sharedCoverageCheck.
  ///
  /// In en, this message translates to:
  /// **'Coverage check'**
  String get sharedCoverageCheck;

  /// No description provided for @sharedYou.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get sharedYou;

  /// No description provided for @sharedLoadingFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the document.'**
  String get sharedLoadingFileFailed;

  /// No description provided for @sharedReviewLater.
  ///
  /// In en, this message translates to:
  /// **'We’ll update this when it’s reviewed.'**
  String get sharedReviewLater;

  /// No description provided for @sharedUploadPrescriptionRetry.
  ///
  /// In en, this message translates to:
  /// **'Upload the doctor’s prescription and try again.'**
  String get sharedUploadPrescriptionRetry;

  /// No description provided for @sharedCanLeave.
  ///
  /// In en, this message translates to:
  /// **'You can leave. We’ll let you know.'**
  String get sharedCanLeave;

  /// No description provided for @sharedFailureOnOurSide.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side.'**
  String get sharedFailureOnOurSide;

  /// No description provided for @sharedAnswerOne.
  ///
  /// In en, this message translates to:
  /// **'Answer 1 question'**
  String get sharedAnswerOne;

  /// No description provided for @sharedTypedByYou.
  ///
  /// In en, this message translates to:
  /// **'Typed by you'**
  String get sharedTypedByYou;

  /// No description provided for @sharedRenewalDate.
  ///
  /// In en, this message translates to:
  /// **'Renewal date'**
  String get sharedRenewalDate;

  /// No description provided for @sharedRenewal.
  ///
  /// In en, this message translates to:
  /// **'Renewal'**
  String get sharedRenewal;

  /// No description provided for @sharedContinuity.
  ///
  /// In en, this message translates to:
  /// **'Continuity'**
  String get sharedContinuity;

  /// No description provided for @sharedDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get sharedDoctor;

  /// No description provided for @sharedPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get sharedPatient;

  /// No description provided for @sharedVisitDate.
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get sharedVisitDate;

  /// No description provided for @sharedTreatmentDate.
  ///
  /// In en, this message translates to:
  /// **'Treatment date'**
  String get sharedTreatmentDate;

  /// No description provided for @sharedForPatient.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String sharedForPatient(String name);

  /// No description provided for @sharedPoliciesCompared.
  ///
  /// In en, this message translates to:
  /// **'{count} policies compared'**
  String sharedPoliciesCompared(int count);

  /// No description provided for @sharedEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String sharedEnded(String date);

  /// No description provided for @sharedEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String sharedEnds(String date);

  /// No description provided for @sharedCoverageAmount.
  ///
  /// In en, this message translates to:
  /// **'₹{amount} cover'**
  String sharedCoverageAmount(String amount);

  /// No description provided for @analysisDetailTranslationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A translation is unavailable for this detail.'**
  String get analysisDetailTranslationUnavailable;

  /// No description provided for @analysisItemDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get analysisItemDiagnosis;

  /// No description provided for @analysisItemTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get analysisItemTest;

  /// No description provided for @analysisItemProcedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get analysisItemProcedure;

  /// No description provided for @analysisItemMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get analysisItemMedicine;

  /// No description provided for @analysisItemConsultation.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get analysisItemConsultation;

  /// No description provided for @analysisItemSymptom.
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get analysisItemSymptom;

  /// No description provided for @analysisViewOriginalQuestion.
  ///
  /// In en, this message translates to:
  /// **'View the original question'**
  String get analysisViewOriginalQuestion;

  /// No description provided for @analysisOriginalOption.
  ///
  /// In en, this message translates to:
  /// **'Original answer option: {option}'**
  String analysisOriginalOption(String option);

  /// No description provided for @analysisAnnexureItemsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Did the bill include any items listed in Annexure I, or were all items essential surgical supplies or included in the package?'**
  String get analysisAnnexureItemsQuestion;

  /// No description provided for @analysisAnnexureItemsYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, it includes items from Annexure I'**
  String get analysisAnnexureItemsYes;

  /// No description provided for @analysisAnnexureItemsNo.
  ///
  /// In en, this message translates to:
  /// **'No, all items are essential surgical supplies or included in the package'**
  String get analysisAnnexureItemsNo;

  /// No description provided for @analysisItemizedBillNeeded.
  ///
  /// In en, this message translates to:
  /// **'Unsure / An itemized bill is needed'**
  String get analysisItemizedBillNeeded;

  /// No description provided for @analysisOptionNumber.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String analysisOptionNumber(int number);

  /// No description provided for @analysisViewOriginalOptions.
  ///
  /// In en, this message translates to:
  /// **'View the original answer options'**
  String get analysisViewOriginalOptions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
