/// Data validation utilities for the events app
/// 
/// Provides validation for various data types including:
/// - Email addresses
/// - Social media links (LinkedIn, Twitter, etc.)
/// - Phone numbers
/// - Website URLs
class DataValidator {
  // Email validation regex
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // LinkedIn URL patterns
  static final List<RegExp> _linkedInRegexes = [
    RegExp(r'^https?://(www\.)?linkedin\.com/in/[a-zA-Z0-9-]+/?$'),
    RegExp(r'^https?://(www\.)?linkedin\.com/pub/[a-zA-Z0-9-]+(/[a-zA-Z0-9-]+){3}/?$'),
    RegExp(r'^https?://(www\.)?linkedin\.com/profile/view\?id=[0-9]+$'),
  ];

  // Twitter URL patterns
  static final List<RegExp> _twitterRegexes = [
    RegExp(r'^https?://(www\.)?(twitter\.com|x\.com)/[a-zA-Z0-9_]+/?$'),
  ];

  // General website URL regex
  static final RegExp _websiteRegex = RegExp(
    r'^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$',
  );

  // Phone number regex (flexible for international formats)
  static final RegExp _phoneRegex = RegExp(
    r'^\+?[1-9]\d{1,14}$|^(\+?\d{1,3}[-.\s]?)?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}$',
  );

  /// Validates email format
  /// Returns null if valid, error message if invalid
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return null; // Allow empty emails
    }
    
    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  /// Validates LinkedIn URL
  /// Returns null if valid, error message if invalid
  static String? validateLinkedIn(String? url) {
    if (url == null || url.isEmpty) {
      return null; // Allow empty URLs
    }

    for (final regex in _linkedInRegexes) {
      if (regex.hasMatch(url)) {
        return null; // Valid LinkedIn URL
      }
    }

    return 'Please enter a valid LinkedIn URL (e.g., https://linkedin.com/in/username)';
  }

  /// Validates Twitter/X URL
  /// Returns null if valid, error message if invalid
  static String? validateTwitter(String? url) {
    if (url == null || url.isEmpty) {
      return null; // Allow empty URLs
    }

    for (final regex in _twitterRegexes) {
      if (regex.hasMatch(url)) {
        return null; // Valid Twitter URL
      }
    }

    return 'Please enter a valid Twitter/X URL (e.g., https://twitter.com/username)';
  }

  /// Validates general website URL
  /// Returns null if valid, error message if invalid
  static String? validateWebsite(String? url) {
    if (url == null || url.isEmpty) {
      return null; // Allow empty URLs
    }

    if (!_websiteRegex.hasMatch(url)) {
      return 'Please enter a valid website URL (must start with http:// or https://)';
    }

    return null;
  }

  /// Validates phone number
  /// Returns null if valid, error message if invalid
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Allow empty phone numbers
    }

    // Remove common formatting characters for validation
    final cleanPhone = phone.replaceAll(RegExp(r'[-.\s()]'), '');
    
    if (!_phoneRegex.hasMatch(cleanPhone)) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Validates required text field
  /// Returns null if valid, error message if invalid
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates text length
  /// Returns null if valid, error message if invalid
  static String? validateLength(String? value, String fieldName, {int? minLength, int? maxLength}) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty values unless specifically required
    }

    if (minLength != null && value.length < minLength) {
      return '$fieldName must be at least $minLength characters long';
    }

    if (maxLength != null && value.length > maxLength) {
      return '$fieldName must be no more than $maxLength characters long';
    }

    return null;
  }

  /// Validates Instagram URL
  /// Returns null if valid, error message if invalid
  static String? validateInstagram(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    final instagramRegex = RegExp(r'^https?://(www\.)?instagram\.com/[a-zA-Z0-9_.]+/?$');
    
    if (!instagramRegex.hasMatch(url)) {
      return 'Please enter a valid Instagram URL (e.g., https://instagram.com/username)';
    }

    return null;
  }

  /// Validates GitHub URL
  /// Returns null if valid, error message if invalid
  static String? validateGitHub(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    final githubRegex = RegExp(r'^https?://(www\.)?github\.com/[a-zA-Z0-9-]+/?$');
    
    if (!githubRegex.hasMatch(url)) {
      return 'Please enter a valid GitHub URL (e.g., https://github.com/username)';
    }

    return null;
  }

  /// Validates Medium URL
  /// Returns null if valid, error message if invalid
  static String? validateMedium(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    final mediumRegexes = [
      RegExp(r'^https?://(www\.)?medium\.com/@[a-zA-Z0-9-_.]+/?$'),
      RegExp(r'^https?://[a-zA-Z0-9-]+\.medium\.com/?$'),
    ];
    
    for (final regex in mediumRegexes) {
      if (regex.hasMatch(url)) {
        return null;
      }
    }

    return 'Please enter a valid Medium URL (e.g., https://medium.com/@username)';
  }

  /// Validates YouTube URL
  /// Returns null if valid, error message if invalid
  static String? validateYouTube(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    final youtubeRegexes = [
      RegExp(r'^https?://(www\.)?youtube\.com/c/[a-zA-Z0-9-]+/?$'),
      RegExp(r'^https?://(www\.)?youtube\.com/channel/[a-zA-Z0-9-_]+/?$'),
      RegExp(r'^https?://(www\.)?youtube\.com/user/[a-zA-Z0-9-]+/?$'),
      RegExp(r'^https?://(www\.)?youtube\.com/@[a-zA-Z0-9-_.]+/?$'),
    ];

    for (final regex in youtubeRegexes) {
      if (regex.hasMatch(url)) {
        return null;
      }
    }

    return 'Please enter a valid YouTube URL';
  }

  /// Validates company name
  /// Returns null if valid, error message if invalid
  static String? validateCompany(String? company) {
    return validateLength(company, 'Company name', maxLength: 100);
  }

  /// Validates job title
  /// Returns null if valid, error message if invalid
  static String? validateTitle(String? title) {
    return validateLength(title, 'Job title', maxLength: 100);
  }

  /// Validates bio
  /// Returns null if valid, error message if invalid
  static String? validateBio(String? bio) {
    return validateLength(bio, 'Bio', maxLength: 500);
  }

  /// Validates name
  /// Returns null if valid, error message if invalid
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Name is required';
    }
    
    if (name.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    
    if (name.length > 50) {
      return 'Name must be no more than 50 characters long';
    }
    
    return null;
  }

  /// Lenient URL validation that auto-corrects common issues
  /// Returns a corrected URL or null if the URL is fundamentally invalid
  static String? normalizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }

    url = url.trim();

    // If it already has protocol, return as-is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Add https:// prefix
    return 'https://$url';
  }

  /// Lenient LinkedIn validation with auto-correction
  static String? validateLinkedInLenient(String? url) {
    if (url == null || url.isEmpty) return null;

    url = url.trim();

    // Handle various LinkedIn formats
    if (url.contains('linkedin.com/in/') || url.contains('linkedin.com/pub/')) {
      // Extract the profile part and rebuild
      final normalized = normalizeUrl(url);
      if (normalized != null) {
        // Basic check for LinkedIn domain
        if (normalized.contains('linkedin.com')) {
          return null; // Valid
        }
      }
    } else if (url.startsWith('@') || (!url.contains('linkedin.com') && !url.contains('http'))) {
      // Might be just a username
      return 'Please enter the full LinkedIn URL (e.g., linkedin.com/in/username)';
    }

    // Try to auto-correct if it's a partial URL
    if (!url.contains('linkedin.com')) {
      return 'Please enter a valid LinkedIn URL';
    }

    return null;
  }

  /// Lenient Twitter validation with auto-correction
  static String? validateTwitterLenient(String? url) {
    if (url == null || url.isEmpty) return null;

    url = url.trim();

    // Handle various Twitter/X formats
    if (url.contains('twitter.com/') || url.contains('x.com/')) {
      final normalized = normalizeUrl(url);
      if (normalized != null) {
        if (normalized.contains('twitter.com') || normalized.contains('x.com')) {
          return null; // Valid
        }
      }
    } else if (url.startsWith('@')) {
      return 'Please enter the full Twitter/X URL (e.g., twitter.com/username)';
    } else if (!url.contains('twitter.com') && !url.contains('x.com') && !url.contains('http')) {
      // Might be just a username
      return 'Please enter the full Twitter/X URL (e.g., twitter.com/username)';
    }

    // Try to auto-correct if it's a partial URL
    if (!url.contains('twitter.com') && !url.contains('x.com')) {
      return 'Please enter a valid Twitter/X URL';
    }

    return null;
  }

  /// Lenient website validation with auto-correction
  static String? validateWebsiteLenient(String? url) {
    if (url == null || url.isEmpty) return null;

    url = url.trim();

    // Very basic domain check
    if (url.contains('.') && url.length > 4) {
      return null; // Probably valid, let the display handle protocol
    }

    return 'Please enter a valid website URL (e.g., example.com)';
  }

  /// Lenient Instagram validation with auto-correction
  static String? validateInstagramLenient(String? url) {
    if (url == null || url.isEmpty) return null;

    url = url.trim();

    if (url.contains('instagram.com/')) {
      final normalized = normalizeUrl(url);
      if (normalized != null && normalized.contains('instagram.com')) {
        return null;
      }
    } else if (url.startsWith('@')) {
      return 'Please enter the full Instagram URL (e.g., instagram.com/username)';
    } else if (!url.contains('instagram.com') && !url.contains('http')) {
      return 'Please enter the full Instagram URL (e.g., instagram.com/username)';
    }

    if (!url.contains('instagram.com')) {
      return 'Please enter a valid Instagram URL';
    }

    return null;
  }

  /// Lenient GitHub validation with auto-correction
  static String? validateGitHubLenient(String? url) {
    if (url == null || url.isEmpty) return null;

    url = url.trim();

    if (url.contains('github.com/')) {
      final normalized = normalizeUrl(url);
      if (normalized != null && normalized.contains('github.com')) {
        return null;
      }
    } else if (!url.contains('github.com') && !url.contains('http')) {
      return 'Please enter the full GitHub URL (e.g., github.com/username)';
    }

    if (!url.contains('github.com')) {
      return 'Please enter a valid GitHub URL';
    }

    return null;
  }

  /// Lenient Medium validation with auto-correction
  static String? validateMediumLenient(String? url) {
    if (url == null || url.isEmpty) return null;

    url = url.trim();

    if (url.contains('medium.com')) {
      final normalized = normalizeUrl(url);
      if (normalized != null && normalized.contains('medium.com')) {
        return null;
      }
    } else if (url.startsWith('@')) {
      return 'Please enter the full Medium URL (e.g., medium.com/@username)';
    } else if (!url.contains('medium.com') && !url.contains('http')) {
      return 'Please enter the full Medium URL (e.g., medium.com/@username)';
    }

    if (!url.contains('medium.com')) {
      return 'Please enter a valid Medium URL';
    }

    return null;
  }
}