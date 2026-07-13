// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DECKARD';

  @override
  String get watchlist => 'WATCHLIST';

  @override
  String get search => 'SEARCH';

  @override
  String get searchHint => 'Search';

  @override
  String get friends => 'FRIENDS';

  @override
  String get profile => 'PROFILE';

  @override
  String get discover => 'DISCOVER';

  @override
  String get trending => 'TRENDING';

  @override
  String get nowPlaying => 'NOW PLAYING';

  @override
  String get forYou => 'FOR YOU';

  @override
  String moviesCount(int count) {
    return '$count MOVIES';
  }

  @override
  String get extendShelf => 'Extend your movie shelf';

  @override
  String get viewRecommendations => 'View recommendations';

  @override
  String get directedBy => 'DIRECTED BY';

  @override
  String get withActors => 'WITH';

  @override
  String get noMoviesAvailable => 'No movies available';

  @override
  String get releaseDate => 'Release Date';

  @override
  String get popularity => 'Popularity';

  @override
  String get languageSelection => 'Select Language';

  @override
  String get cast => 'CAST';

  @override
  String get crew => 'CREW';

  @override
  String get genres => 'GENRES';

  @override
  String get details => 'DETAILS';

  @override
  String get reviews => 'REVIEWS';

  @override
  String get similarMovies => 'SIMILAR MOVIES';

  @override
  String get tagline => 'Tagline';

  @override
  String get runtime => 'Runtime';

  @override
  String minutes(int min) {
    return '$min min';
  }

  @override
  String get originalTitle => 'Original Title';

  @override
  String get status => 'Status';

  @override
  String get budget => 'Budget';

  @override
  String get revenue => 'Revenue';

  @override
  String get trailer => 'TRAILER';

  @override
  String get ratings => 'Ratings';

  @override
  String get logYourWatch => 'Log this film';

  @override
  String get editYourRating => 'Edit your log';

  @override
  String get watched => 'Watched';

  @override
  String get liked => 'Liked';

  @override
  String get watch => 'Watch';

  @override
  String get like => 'Like';

  @override
  String get rate => 'Rate';

  @override
  String get watchlistAdd => 'Watchlist';

  @override
  String get removeWatchlist => 'Remove from Watchlist';

  @override
  String get watchlistEmpty => 'Watchlist empty';

  @override
  String get goToDiscover => 'Go to Discover';

  @override
  String get you => 'YOU';

  @override
  String get writeReview => 'Write a review...';

  @override
  String get submit => 'Submit';

  @override
  String get allReviews => 'ALL REVIEWS';

  @override
  String get recentSearches => 'RECENT SEARCHES';

  @override
  String get films => 'Films';

  @override
  String get castCrew => 'Cast or Crew';

  @override
  String get noResults => 'No results found';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get directedByLower => 'directed by';

  @override
  String get withActorsLower => 'with';

  @override
  String get newReleases => 'New releases';

  @override
  String get favoritesTab => 'FAVORITES';

  @override
  String get watchedTab => 'WATCHED';

  @override
  String get ratingsTab => 'RATINGS';

  @override
  String get memberSince => 'Member since';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get save => 'Save';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get noWatched => 'No watched films yet';

  @override
  String get noRatingsYet => 'No ratings yet';

  @override
  String get languageLabel => 'LANGUAGE';

  @override
  String get usernameLabel => 'USERNAME';

  @override
  String get emailLabel => 'EMAIL ADDRESS';

  @override
  String get changePasswordLabel => 'CHANGE PASSWORD';

  @override
  String get changePasswordHint => 'Leave blank to keep your current password.';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get confirmPasswordLabel => 'CONFIRM PASSWORD';

  @override
  String get passwordMismatch => 'Passwords don\'t match';

  @override
  String get profileNotLoggedIn => 'Sign in to see your profile';

  @override
  String get retry => 'Retry';

  @override
  String get watchWithFriends => 'Watch with friends';

  @override
  String get startAMatch => 'Start a match';

  @override
  String get joinAMatch => 'Join a match';

  @override
  String get popularWithFriends => 'POPULAR WITH FRIENDS';

  @override
  String get myFriends => 'MY FRIENDS';

  @override
  String get noFriendsYet => 'No friends yet. Add some!';

  @override
  String get addFriend => 'Add a friend';

  @override
  String get friendRequests => 'FRIEND REQUESTS';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get sendRequest => 'Send request';

  @override
  String get searchUsername => 'Search by username';

  @override
  String get friendRequestSent => 'Request sent!';

  @override
  String get join => 'Join';

  @override
  String get match => 'Match';

  @override
  String get groupMatch => 'Group Match';

  @override
  String get gatherGroupTastes => 'Discover what the group wants to watch';

  @override
  String get friendsWhoJoined => 'FRIENDS WHO JOINED';

  @override
  String get orUseCode => 'OR USE CODE';

  @override
  String get goButton => 'GO';

  @override
  String get waitingForHost => 'Waiting for the host to start…';

  @override
  String get waitingForOthers => 'Waiting for the others to finish…';

  @override
  String get codeCopied => 'Code copied!';

  @override
  String get makeYourSelection => 'Make your selection';

  @override
  String get declineMovie => 'Decline';

  @override
  String get selectMovie => 'Select';

  @override
  String get matchResults => 'Match results';

  @override
  String get unanimousMovies => 'YOU ALL AGREE ON THESE';

  @override
  String get unanimousMoviesSubtitle =>
      'Everyone in the group selected these films.';

  @override
  String get noMatchFound => 'No match this time!';

  @override
  String get noMatchFoundSubtitle =>
      'Your group couldn\'t agree on a film. Try again with different choices.';

  @override
  String get restartMatch => 'Start a new match';

  @override
  String get loginSubtitle => 'Discover films. Together.';

  @override
  String get passwordLabel => 'PASSWORD';

  @override
  String get loginButton => 'Log in';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutConfirm => 'Are you sure you want to log out?';

  @override
  String get cancel => 'Cancel';

  @override
  String get loginTab => 'Log in';

  @override
  String get registerTab => 'Sign up';

  @override
  String get registerButton => 'Create account';

  @override
  String get usernameTooShort => 'At least 3 characters';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get onboardingTitle => 'What films do you love?';

  @override
  String get onboardingSubtitle =>
      'Pick 1 to 10 films to personalize your experience.';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String onboardingCounter(int count, int max) {
    return '$count / $max selected';
  }

  @override
  String get filmography => 'Filmography';

  @override
  String get biography => 'Biography';

  @override
  String get noFilmography => 'No films found in our catalogue.';

  @override
  String get noReviewsYet => 'No reviews yet.';

  @override
  String get movieRecommendations => 'Movie Recommendations';

  @override
  String get deckardAi => 'Deckard AI';

  @override
  String get basedOnYourTastes => 'based on your tastes';

  @override
  String get addFilters => 'Add filters';

  @override
  String get filterTitle => 'Filters';

  @override
  String get clearFilters => 'Clear';

  @override
  String get periodFilter => 'PERIOD';

  @override
  String get genreFilter => 'GENRES';

  @override
  String get applyFilters => 'Apply';

  @override
  String get noRecommendationsFound => 'No recommendations match your filters.';

  @override
  String get addedToWatchlist => 'added to your watchlist.';

  @override
  String get scanQrCode => 'Scan a QR code';

  @override
  String get scanQrHint => 'Point the camera at the match QR code to join';
}
