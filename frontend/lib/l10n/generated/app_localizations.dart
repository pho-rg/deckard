import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DECKARD'**
  String get appTitle;

  /// No description provided for @watchlist.
  ///
  /// In en, this message translates to:
  /// **'WATCHLIST'**
  String get watchlist;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'SEARCH'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'FRIENDS'**
  String get friends;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profile;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'DISCOVER'**
  String get discover;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'TRENDING'**
  String get trending;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'NOW PLAYING'**
  String get nowPlaying;

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'FOR YOU'**
  String get forYou;

  /// No description provided for @moviesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} MOVIES'**
  String moviesCount(int count);

  /// No description provided for @extendShelf.
  ///
  /// In en, this message translates to:
  /// **'Extend your movie shelf'**
  String get extendShelf;

  /// No description provided for @viewRecommendations.
  ///
  /// In en, this message translates to:
  /// **'View recommendations'**
  String get viewRecommendations;

  /// No description provided for @directedBy.
  ///
  /// In en, this message translates to:
  /// **'DIRECTED BY'**
  String get directedBy;

  /// No description provided for @withActors.
  ///
  /// In en, this message translates to:
  /// **'WITH'**
  String get withActors;

  /// No description provided for @noMoviesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No movies available'**
  String get noMoviesAvailable;

  /// No description provided for @releaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get releaseDate;

  /// No description provided for @popularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get popularity;

  /// No description provided for @languageSelection.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get languageSelection;

  /// No description provided for @cast.
  ///
  /// In en, this message translates to:
  /// **'CAST'**
  String get cast;

  /// No description provided for @crew.
  ///
  /// In en, this message translates to:
  /// **'CREW'**
  String get crew;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'GENRES'**
  String get genres;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get details;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'REVIEWS'**
  String get reviews;

  /// No description provided for @similarMovies.
  ///
  /// In en, this message translates to:
  /// **'SIMILAR MOVIES'**
  String get similarMovies;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get tagline;

  /// No description provided for @runtime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get runtime;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{min} min'**
  String minutes(int min);

  /// No description provided for @originalTitle.
  ///
  /// In en, this message translates to:
  /// **'Original Title'**
  String get originalTitle;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @trailer.
  ///
  /// In en, this message translates to:
  /// **'TRAILER'**
  String get trailer;

  /// No description provided for @ratings.
  ///
  /// In en, this message translates to:
  /// **'RATINGS'**
  String get ratings;

  /// No description provided for @logYourWatch.
  ///
  /// In en, this message translates to:
  /// **'Log this film'**
  String get logYourWatch;

  /// No description provided for @editYourRating.
  ///
  /// In en, this message translates to:
  /// **'Edit your log'**
  String get editYourRating;

  /// No description provided for @watched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get watched;

  /// No description provided for @liked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get liked;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @watchlistAdd.
  ///
  /// In en, this message translates to:
  /// **'Watchlist'**
  String get watchlistAdd;

  /// No description provided for @removeWatchlist.
  ///
  /// In en, this message translates to:
  /// **'Remove from Watchlist'**
  String get removeWatchlist;

  /// No description provided for @watchlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Watchlist empty'**
  String get watchlistEmpty;

  /// No description provided for @goToDiscover.
  ///
  /// In en, this message translates to:
  /// **'Go to Discover'**
  String get goToDiscover;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get you;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review...'**
  String get writeReview;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @allReviews.
  ///
  /// In en, this message translates to:
  /// **'ALL REVIEWS'**
  String get allReviews;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'RECENT SEARCHES'**
  String get recentSearches;

  /// No description provided for @films.
  ///
  /// In en, this message translates to:
  /// **'Films'**
  String get films;

  /// No description provided for @castCrew.
  ///
  /// In en, this message translates to:
  /// **'Cast or Crew'**
  String get castCrew;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @directedByLower.
  ///
  /// In en, this message translates to:
  /// **'directed by'**
  String get directedByLower;

  /// No description provided for @withActorsLower.
  ///
  /// In en, this message translates to:
  /// **'with'**
  String get withActorsLower;

  /// No description provided for @newReleases.
  ///
  /// In en, this message translates to:
  /// **'New releases'**
  String get newReleases;

  /// No description provided for @favoritesTab.
  ///
  /// In en, this message translates to:
  /// **'FAVORITES'**
  String get favoritesTab;

  /// No description provided for @watchedTab.
  ///
  /// In en, this message translates to:
  /// **'WATCHED'**
  String get watchedTab;

  /// No description provided for @ratingsTab.
  ///
  /// In en, this message translates to:
  /// **'RATINGS'**
  String get ratingsTab;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @noWatched.
  ///
  /// In en, this message translates to:
  /// **'No watched films yet'**
  String get noWatched;

  /// No description provided for @noRatingsYet.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get noRatingsYet;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get languageLabel;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'USERNAME'**
  String get usernameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'EMAIL ADDRESS'**
  String get emailLabel;

  /// No description provided for @changePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'CHANGE PASSWORD'**
  String get changePasswordLabel;

  /// No description provided for @changePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep your current password.'**
  String get changePasswordHint;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordMismatch;

  /// No description provided for @profileNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your profile'**
  String get profileNotLoggedIn;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @watchWithFriends.
  ///
  /// In en, this message translates to:
  /// **'Watch with friends'**
  String get watchWithFriends;

  /// No description provided for @startAMatch.
  ///
  /// In en, this message translates to:
  /// **'Start a match'**
  String get startAMatch;

  /// No description provided for @joinAMatch.
  ///
  /// In en, this message translates to:
  /// **'Join a match'**
  String get joinAMatch;

  /// No description provided for @popularWithFriends.
  ///
  /// In en, this message translates to:
  /// **'POPULAR WITH FRIENDS'**
  String get popularWithFriends;

  /// No description provided for @myFriends.
  ///
  /// In en, this message translates to:
  /// **'MY FRIENDS'**
  String get myFriends;

  /// No description provided for @noFriendsYet.
  ///
  /// In en, this message translates to:
  /// **'No friends yet. Add some!'**
  String get noFriendsYet;

  /// No description provided for @addFriend.
  ///
  /// In en, this message translates to:
  /// **'Add a friend'**
  String get addFriend;

  /// No description provided for @friendRequests.
  ///
  /// In en, this message translates to:
  /// **'FRIEND REQUESTS'**
  String get friendRequests;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @searchUsername.
  ///
  /// In en, this message translates to:
  /// **'Search by username'**
  String get searchUsername;

  /// No description provided for @friendRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent!'**
  String get friendRequestSent;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @match.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get match;

  /// No description provided for @groupMatch.
  ///
  /// In en, this message translates to:
  /// **'Group Match'**
  String get groupMatch;

  /// No description provided for @gatherGroupTastes.
  ///
  /// In en, this message translates to:
  /// **'Discover what the group wants to watch'**
  String get gatherGroupTastes;

  /// No description provided for @friendsWhoJoined.
  ///
  /// In en, this message translates to:
  /// **'FRIENDS WHO JOINED'**
  String get friendsWhoJoined;

  /// No description provided for @orUseCode.
  ///
  /// In en, this message translates to:
  /// **'OR USE CODE'**
  String get orUseCode;

  /// No description provided for @goButton.
  ///
  /// In en, this message translates to:
  /// **'GO'**
  String get goButton;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start…'**
  String get waitingForHost;

  /// No description provided for @waitingForOthers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the others to finish…'**
  String get waitingForOthers;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied!'**
  String get codeCopied;

  /// No description provided for @makeYourSelection.
  ///
  /// In en, this message translates to:
  /// **'Make your selection'**
  String get makeYourSelection;

  /// No description provided for @declineMovie.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineMovie;

  /// No description provided for @selectMovie.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectMovie;

  /// No description provided for @matchResults.
  ///
  /// In en, this message translates to:
  /// **'Match results'**
  String get matchResults;

  /// No description provided for @unanimousMovies.
  ///
  /// In en, this message translates to:
  /// **'YOU ALL AGREE ON THESE'**
  String get unanimousMovies;

  /// No description provided for @unanimousMoviesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the group selected these films.'**
  String get unanimousMoviesSubtitle;

  /// No description provided for @noMatchFound.
  ///
  /// In en, this message translates to:
  /// **'No match this time!'**
  String get noMatchFound;

  /// No description provided for @noMatchFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your group couldn\'t agree on a film. Try again with different choices.'**
  String get noMatchFoundSubtitle;

  /// No description provided for @restartMatch.
  ///
  /// In en, this message translates to:
  /// **'Start a new match'**
  String get restartMatch;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover films. Together.'**
  String get loginSubtitle;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get passwordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logOutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loginTab.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTab;

  /// No description provided for @registerTab.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get registerTab;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerButton;

  /// No description provided for @usernameTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters'**
  String get usernameTooShort;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'What films do you love?'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick 1 to 10 films to personalize your experience.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingCounter.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max} selected'**
  String onboardingCounter(int count, int max);

  /// No description provided for @filmography.
  ///
  /// In en, this message translates to:
  /// **'Filmography'**
  String get filmography;

  /// No description provided for @biography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get biography;

  /// No description provided for @noFilmography.
  ///
  /// In en, this message translates to:
  /// **'No films found in our catalogue.'**
  String get noFilmography;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get noReviewsYet;

  /// No description provided for @movieRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Movie Recommendations'**
  String get movieRecommendations;

  /// No description provided for @deckardAi.
  ///
  /// In en, this message translates to:
  /// **'Deckard AI'**
  String get deckardAi;

  /// No description provided for @basedOnYourTastes.
  ///
  /// In en, this message translates to:
  /// **'based on your tastes'**
  String get basedOnYourTastes;

  /// No description provided for @addFilters.
  ///
  /// In en, this message translates to:
  /// **'Add filters'**
  String get addFilters;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filterTitle;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// No description provided for @periodFilter.
  ///
  /// In en, this message translates to:
  /// **'PERIOD'**
  String get periodFilter;

  /// No description provided for @genreFilter.
  ///
  /// In en, this message translates to:
  /// **'GENRES'**
  String get genreFilter;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyFilters;

  /// No description provided for @noRecommendationsFound.
  ///
  /// In en, this message translates to:
  /// **'No recommendations match your filters.'**
  String get noRecommendationsFound;

  /// No description provided for @addedToWatchlist.
  ///
  /// In en, this message translates to:
  /// **'added to your watchlist.'**
  String get addedToWatchlist;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get scanQrCode;

  /// No description provided for @scanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the match QR code to join'**
  String get scanQrHint;
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
