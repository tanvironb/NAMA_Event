import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive seed data for testing the events app
/// 
/// ALL USERS HAVE PASSWORD: "abc123"
/// 
/// NOTE: When adding new social media fields (github, medium, instagram),
/// make sure to add them to ALL user entries in the format:
/// 'github': 'https://github.com/username' (or '' if empty)
/// 'medium': 'https://medium.com/@username' (or '' if empty)  
/// 'instagram': 'https://instagram.com/username' (or '' if empty)
/// 
/// Test Accounts:
/// - admin@techconf2024.dev (Admin)
/// - registration@techconf2024.dev (Staff)
/// - tech@techconf2024.dev (Staff)
/// - sarah.chen@flutterdev.com (Speaker)
/// - alex.martinez@google.com (Speaker)
/// - maya.patel@designstudio.com (Speaker)
/// - david.kim@microsoft.com (Speaker)
/// - rebecca.torres@meta.com (Speaker)
/// - james.wilson@aws.com (Speaker)
/// - john.doe@techcorp.com (Attendee)
/// - jane.smith@startup.io (Attendee)
/// - mike.johnson@freelance.dev (Pending User)
/// - lisa.wong@university.edu (Attendee)
/// - carlos.rivera@enterprise.com (Attendee)
class SeedData {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Main method to seed all data
  /// Note: All users will be created with password "abc123"
  static Future<void> seedAllData() async {
    debugPrint('🌱 Starting comprehensive data seeding...');
    
    // Clear existing data first (optional)
    await _clearExistingData();
    
    // Seed in order due to dependencies
    final eventId = await _seedEvents();
    await _seedSponsors(eventId);
    await _seedUsers();
    await _seedSessions(eventId);
    
    debugPrint('🌱 Data seeding completed successfully!');
  }

  /// Clear existing data (optional - be careful in production!)
  static Future<void> _clearExistingData() async {
    debugPrint('🧹 Clearing existing data...');
    
    final collections = ['events', 'sponsors', 'sessions', 'users'];
    for (String collection in collections) {
      await _clearCollection(collection);
    }
  }

  static Future<void> _clearCollection(String collectionName) async {
    final batch = _db.batch();
    final snapshot = await _db.collection(collectionName).limit(500).get();
    
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    debugPrint('🧹 Cleared $collectionName collection');
  }

  /// Seed events data
  static Future<String> _seedEvents() async {
    debugPrint('🎯 Seeding events...');
    
    final eventRef = _db.collection('events').doc();
    await eventRef.set({
      'name': 'TechConf 2024: Future of Mobile Development',
      'description': 'The premier technology conference bringing together mobile developers, AI specialists, and industry leaders. Join us for three days of learning, networking, and innovation.',
      'location': 'San Francisco Convention Center, CA',
      'venue': 'Moscone Center',
      'address': '747 Howard St, San Francisco, CA 94103',
      'startDate': Timestamp.fromDate(DateTime(2024, 11, 15)),
      'endDate': Timestamp.fromDate(DateTime(2024, 11, 17)),
      'isActive': true,
      'website': 'https://techconf2024.dev',
      'maxAttendees': 2500,
      'currentAttendees': 1847,
      'ticketPrice': 599.99,
      'earlyBirdPrice': 449.99,
      'studentPrice': 199.99,
      'themes': ['Mobile Development', 'AI/ML', 'Cloud Computing', 'DevOps', 'Web3'],
      'hashtags': ['#TechConf2024', '#MobileDev', '#Innovation'],
      'organizer': {
        'name': 'TechEvents Inc.',
        'email': 'info@techconf2024.dev',
        'phone': '+1-555-0123',
      },
      'socialMedia': {
        'twitter': 'https://twitter.com/techconf2024',
        'linkedin': 'https://linkedin.com/company/techconf2024',
        'instagram': 'https://instagram.com/techconf2024',
        'youtube': 'https://youtube.com/c/techconf2024',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    debugPrint('✅ Events seeded');
    return eventRef.id;
  }

  /// Seed sponsors data
  static Future<void> _seedSponsors(String eventId) async {
    debugPrint('🏢 Seeding sponsors...');
    
    final sponsors = [
      // Platinum Sponsors
      {
        'eventId': eventId,
        'name': 'Google',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/2/2f/Google_2015_logo.svg',
        'website': 'https://developers.google.com/flutter',
        'description': 'Google is the creator of Flutter and a leading technology company driving innovation in mobile development, AI, and cloud computing.',
        'tier': 'platinum',
        'sponsorshipAmount': 150000,
        'benefits': ['Keynote slot', 'Main stage branding', 'Premium booth space', 'VIP networking access'],
        'contact': {
          'name': 'Jennifer Martinez',
          'email': 'partnerships@google.com',
          'phone': '+1-650-555-0100',
        },
      },
      {
        'eventId': eventId,
        'name': 'Microsoft',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/9/96/Microsoft_logo_%282012%29.svg',
        'website': 'https://azure.microsoft.com',
        'description': 'Microsoft Azure provides comprehensive cloud solutions and development tools for modern applications.',
        'tier': 'platinum',
        'sponsorshipAmount': 140000,
        'benefits': ['Workshop space', 'Demo stations', 'Premium booth', 'Networking dinner sponsor'],
        'contact': {
          'name': 'Robert Chen',
          'email': 'events@microsoft.com',
          'phone': '+1-425-555-0200',
        },
      },
      
      // Gold Sponsors
      {
        'eventId': eventId,
        'name': 'Amazon Web Services',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/9/93/Amazon_Web_Services_Logo.svg',
        'website': 'https://aws.amazon.com',
        'description': 'AWS offers reliable, scalable, and inexpensive cloud computing services for mobile and web applications.',
        'tier': 'gold',
        'sponsorshipAmount': 75000,
        'benefits': ['Technical session', 'Standard booth', 'Coffee break sponsor'],
        'contact': {
          'name': 'Sarah Wilson',
          'email': 'events@aws.amazon.com',
          'phone': '+1-206-555-0300',
        },
      },
      {
        'eventId': eventId,
        'name': 'Meta',
        'logoUrl': 'https://upload.wikimedia.org/wikipedia/commons/7/7b/Meta_Platforms_Inc._logo.svg',
        'website': 'https://developers.facebook.com',
        'description': 'Meta builds technologies that help people connect, find communities, and grow businesses through VR, AR, and social platforms.',
        'tier': 'gold',
        'sponsorshipAmount': 70000,
        'benefits': ['VR demo space', 'Standard booth', 'Lunch sponsor'],
        'contact': {
          'name': 'Alex Thompson',
          'email': 'developer-events@meta.com',
          'phone': '+1-650-555-0400',
        },
      },
      {
        'eventId': eventId,
        'name': 'Shopify',
        'logoUrl': 'https://cdn.shopify.com/assets2/brand-assets/shopify-logo-primary-logo-456baa801ee66a58435eb6d73b8ac7f4.png',
        'website': 'https://shopify.dev',
        'description': 'Shopify provides a commerce platform that helps millions of businesses sell online, in-store, and everywhere in between.',
        'tier': 'gold',
        'sponsorshipAmount': 65000,
        'benefits': ['Commerce workshop', 'Demo stations', 'Standard booth'],
        'contact': {
          'name': 'Emily Rodriguez',
          'email': 'partnerships@shopify.com',
          'phone': '+1-613-555-0500',
        },
      },
      
      // Silver Sponsors
      {
        'eventId': eventId,
        'name': 'Firebase',
        'logoUrl': 'https://firebase.google.com/images/brand-guidelines/logo-logomark.png',
        'website': 'https://firebase.google.com',
        'description': 'Firebase provides backend services, easy-to-use SDKs, and ready-made UI libraries for mobile and web apps.',
        'tier': 'silver',
        'sponsorshipAmount': 35000,
        'benefits': ['Technical session', 'Small booth', 'Swag distribution'],
        'contact': {
          'name': 'David Park',
          'email': 'firebase-events@google.com',
          'phone': '+1-650-555-0600',
        },
      },
      {
        'eventId': eventId,
        'name': 'MongoDB',
        'logoUrl': 'https://webassets.mongodb.com/_com_assets/cms/mongodb_logo1-76twgcu2dm.png',
        'website': 'https://mongodb.com',
        'description': 'MongoDB is a document database designed for ease of development and scaling for modern applications.',
        'tier': 'silver',
        'sponsorshipAmount': 30000,
        'benefits': ['Database workshop', 'Small booth', 'Happy hour sponsor'],
        'contact': {
          'name': 'Lisa Kumar',
          'email': 'events@mongodb.com',
          'phone': '+1-646-555-0700',
        },
      },
      {
        'eventId': eventId,
        'name': 'Stripe',
        'logoUrl': 'https://images.ctfassets.net/fzn2n1nzq965/HTTOloNPhisV9P4hlMPNA/cacf1bb88b9fc492dfad34378d844280/Stripe_icon_-_square.svg',
        'website': 'https://stripe.com/docs',
        'description': 'Stripe builds economic infrastructure for the internet, providing payment processing APIs for online businesses.',
        'tier': 'silver',
        'sponsorshipAmount': 32000,
        'benefits': ['Payments workshop', 'Small booth', 'Networking sponsor'],
        'contact': {
          'name': 'Michael Chang',
          'email': 'partnerships@stripe.com',
          'phone': '+1-415-555-0800',
        },
      },
      
      // Bronze Sponsors
      {
        'eventId': eventId,
        'name': 'Twilio',
        'logoUrl': 'https://www.twilio.com/content/dam/twilio-com/global/en/blog/legacy/2017/TwilioLogo_Red.png',
        'website': 'https://twilio.com/docs',
        'description': 'Twilio provides cloud communications platform APIs for messaging, voice, video, and authentication.',
        'tier': 'bronze',
        'sponsorshipAmount': 15000,
        'benefits': ['Small booth', 'Swag distribution'],
        'contact': {
          'name': 'Jessica Lee',
          'email': 'events@twilio.com',
          'phone': '+1-415-555-0900',
        },
      },
      {
        'eventId': eventId,
        'name': 'Supabase',
        'logoUrl': 'https://supabase.com/_next/image?url=%2F_next%2Fstatic%2Fmedia%2Flogo-preview.50e0b9c0.jpg&w=256&q=75',
        'website': 'https://supabase.com',
        'description': 'Supabase is an open source Firebase alternative providing database, authentication, and real-time subscriptions.',
        'tier': 'bronze',
        'sponsorshipAmount': 12000,
        'benefits': ['Small booth', 'Swag distribution'],
        'contact': {
          'name': 'Tom Anderson',
          'email': 'partnerships@supabase.com',
          'phone': '+1-555-0123',
        },
      },
    ];

    final batch = _db.batch();
    for (var sponsor in sponsors) {
      final ref = _db.collection('sponsors').doc();
      batch.set(ref, {
        ...sponsor,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('✅ Sponsors seeded');
  }

  /// Seed users data with realistic profiles
  static Future<void> _seedUsers() async {
    debugPrint('👥 Seeding users...');
    
    final users = [
      // Admin Users
      {
        'uid': 'admin_001',
        'email': 'admin@techconf2024.dev',
        'name': 'Conference Administrator',
        'role': 'admin',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face',
        'company': 'TechEvents Inc.',
        'title': 'Event Director',
        'bio': 'Experienced event organizer specializing in technology conferences and developer communities.',
        'phone': '+1-555-0101',
        'linkedin': 'https://linkedin.com/in/conferencedirector',
        'twitter': 'https://twitter.com/techconf_admin',
        'website': 'https://techconf2024.dev',
        'qrCodePayload': 'admin_001',
        'visibleInDirectory': true,
        'bookmarkedSessions': [],
        'points': 0,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      
      // Staff Users
      {
        'uid': 'staff_001',
        'email': 'registration@techconf2024.dev',
        'name': 'Emma Johnson',
        'role': 'staff',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1494790108755-2616b612b602?w=400&h=400&fit=crop&crop=face',
        'company': 'TechEvents Inc.',
        'title': 'Registration Manager',
        'bio': 'Registration and attendee experience specialist ensuring smooth conference operations.',
        'phone': '+1-555-0102',
        'linkedin': 'https://linkedin.com/in/emmajohnson',
        'twitter': 'https://twitter.com/emma_events',
        'website': '',
        'qrCodePayload': 'staff_001',
        'visibleInDirectory': true,
        'bookmarkedSessions': [],
        'points': 0,
        'notificationsEnabled': true,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'staff_002',
        'email': 'tech@techconf2024.dev',
        'name': 'Marcus Rodriguez',
        'role': 'staff',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face',
        'company': 'TechEvents Inc.',
        'title': 'Technical Operations',
        'bio': 'A/V and technical setup specialist ensuring all sessions run smoothly.',
        'phone': '+1-555-0103',
        'linkedin': 'https://linkedin.com/in/marcusrodriguez',
        'twitter': 'https://twitter.com/marcus_tech',
        'website': '',
        'qrCodePayload': 'staff_002',
        'visibleInDirectory': true,
        'bookmarkedSessions': [],
        'points': 0,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      
      // Speaker Users
      {
        'uid': 'speaker_001',
        'email': 'sarah.chen@flutterdev.com',
        'name': 'Dr. Sarah Chen',
        'role': 'speaker',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&h=400&fit=crop&crop=face',
        'company': 'Flutter Technologies',
        'title': 'Senior Flutter Architect',
        'bio': 'Flutter GDE with 10+ years in mobile development. Author of "Modern Flutter Architecture" and creator of popular open-source packages. Passionate about state management and performance optimization.',
        'phone': '+1-555-0201',
        'linkedin': 'https://linkedin.com/in/drsarahchen',
        'twitter': 'https://twitter.com/sarahflutter',
        'website': 'https://sarahchen.dev',
        'github': 'https://github.com/sarahchen',
        'medium': 'https://medium.com/@sarahchen',
        'instagram': '',
        'qrCodePayload': 'speaker_001',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_001', 'session_015'],
        'points': 850,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'speaker_002',
        'email': 'alex.martinez@google.com',
        'name': 'Alex Martinez',
        'role': 'speaker',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face',
        'company': 'Google',
        'title': 'Flutter Team Lead',
        'bio': 'Core Flutter team member focusing on performance and developer experience. Previously worked on Android framework and loves building developer tools.',
        'phone': '+1-555-0202',
        'linkedin': 'https://linkedin.com/in/alexmartinez',
        'twitter': 'https://twitter.com/alex_flutter',
        'website': 'https://alexmartinez.dev',
        'github': 'https://github.com/alexmartinez',
        'medium': '',
        'instagram': 'https://instagram.com/alexcodes',
        'qrCodePayload': 'speaker_002',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_001', 'session_008'],
        'points': 1200,
        'notificationsEnabled': true,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'speaker_003',
        'email': 'maya.patel@designstudio.com',
        'name': 'Maya Patel',
        'role': 'speaker',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face',
        'company': 'Design Studio Pro',
        'title': 'Principal UX Designer',
        'bio': 'Award-winning designer specializing in mobile UX and design systems. Advocate for accessible design and smooth developer-designer collaboration.',
        'phone': '+1-555-0203',
        'linkedin': 'https://linkedin.com/in/mayapatel',
        'twitter': 'https://twitter.com/maya_designs',
        'website': 'https://mayapatel.design',
        'qrCodePayload': 'speaker_003',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_003', 'session_012'],
        'points': 650,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'speaker_004',
        'email': 'david.kim@microsoft.com',
        'name': 'David Kim',
        'role': 'speaker',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face',
        'company': 'Microsoft',
        'title': 'Principal Software Engineer',
        'bio': 'Cloud architecture expert with focus on Azure services and mobile backend solutions. Passionate about scalable systems and DevOps practices.',
        'phone': '+1-555-0204',
        'linkedin': 'https://linkedin.com/in/davidkim',
        'twitter': 'https://twitter.com/david_cloud',
        'website': 'https://davidkim.tech',
        'qrCodePayload': 'speaker_004',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_006', 'session_014'],
        'points': 920,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'speaker_005',
        'email': 'rebecca.torres@meta.com',
        'name': 'Rebecca Torres',
        'role': 'speaker',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1494790108755-2616b612b602?w=400&h=400&fit=crop&crop=face',
        'company': 'Meta',
        'title': 'VR/AR Platform Engineer',
        'bio': 'Pioneering the future of immersive experiences with VR/AR technologies. Expert in 3D graphics, spatial computing, and cross-platform development.',
        'phone': '+1-555-0205',
        'linkedin': 'https://linkedin.com/in/rebeccatorres',
        'twitter': 'https://twitter.com/rebecca_vr',
        'website': 'https://rebeccatorres.dev',
        'qrCodePayload': 'speaker_005',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_009', 'session_016'],
        'points': 780,
        'notificationsEnabled': true,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'speaker_006',
        'email': 'james.wilson@aws.com',
        'name': 'James Wilson',
        'role': 'speaker',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face',
        'company': 'Amazon Web Services',
        'title': 'Solutions Architect',
        'bio': 'Serverless and cloud-native advocate helping developers build scalable applications. Expert in AWS services, microservices, and container orchestration.',
        'phone': '+1-555-0206',
        'linkedin': 'https://linkedin.com/in/jameswilson',
        'twitter': 'https://twitter.com/james_aws',
        'website': 'https://jameswilson.cloud',
        'qrCodePayload': 'speaker_006',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_007', 'session_013'],
        'points': 1050,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      
      // Regular Attendee Users
      {
        'uid': 'user_001',
        'email': 'john.doe@techcorp.com',
        'name': 'John Doe',
        'role': 'user',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face',
        'company': 'TechCorp Solutions',
        'title': 'Senior Mobile Developer',
        'bio': 'Mobile developer with 5 years of experience in Flutter and React Native. Always eager to learn new technologies.',
        'phone': '+1-555-0301',
        'linkedin': 'https://linkedin.com/in/johndoe',
        'twitter': 'https://twitter.com/john_dev',
        'website': '',
        'qrCodePayload': 'user_001',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_001', 'session_003', 'session_008'],
        'points': 240,
        'notificationsEnabled': true,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_002',
        'email': 'jane.smith@startup.io',
        'name': 'Jane Smith',
        'role': 'user',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face',
        'company': 'Startup Innovations',
        'title': 'CTO',
        'bio': 'Tech startup founder passionate about building innovative mobile experiences.',
        'phone': '+1-555-0302',
        'linkedin': 'https://linkedin.com/in/janesmith',
        'twitter': 'https://twitter.com/jane_cto',
        'website': 'https://startup.io',
        'qrCodePayload': 'user_002',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_002', 'session_004', 'session_011'],
        'points': 180,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_003',
        'email': 'mike.johnson@freelance.dev',
        'name': 'Mike Johnson',
        'role': 'user',
        'status': 'pending',
        'profileImageUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face',
        'company': 'Freelance Developer',
        'title': 'Flutter Consultant',
        'bio': 'Independent Flutter consultant helping businesses build cross-platform mobile applications.',
        'phone': '+1-555-0303',
        'linkedin': 'https://linkedin.com/in/mikejohnson',
        'twitter': 'https://twitter.com/mike_flutter',
        'website': 'https://mikejohnson.dev',
        'qrCodePayload': 'user_003',
        'visibleInDirectory': true,
        'bookmarkedSessions': [],
        'points': 0,
        'notificationsEnabled': true,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_004',
        'email': 'lisa.wong@university.edu',
        'name': 'Lisa Wong',
        'role': 'user',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1494790108755-2616b612b602?w=400&h=400&fit=crop&crop=face',
        'company': 'University of Technology',
        'title': 'Computer Science Student',
        'bio': 'CS student passionate about mobile development and machine learning. Intern at a local tech company.',
        'phone': '+1-555-0304',
        'linkedin': 'https://linkedin.com/in/lisawong',
        'twitter': 'https://twitter.com/lisa_codes',
        'website': '',
        'qrCodePayload': 'user_004',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_001', 'session_005', 'session_010'],
        'points': 120,
        'notificationsEnabled': true,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'user_005',
        'email': 'carlos.rivera@enterprise.com',
        'name': 'Carlos Rivera',
        'role': 'user',
        'status': 'approved',
        'profileImageUrl': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face',
        'company': 'Enterprise Solutions Inc.',
        'title': 'Technical Lead',
        'bio': 'Enterprise software architect with focus on scalable mobile solutions and team leadership.',
        'phone': '+1-555-0305',
        'linkedin': 'https://linkedin.com/in/carlosrivera',
        'twitter': 'https://twitter.com/carlos_tech',
        'website': '',
        'qrCodePayload': 'user_005',
        'visibleInDirectory': true,
        'bookmarkedSessions': ['session_006', 'session_007', 'session_014'],
        'points': 320,
        'notificationsEnabled': true,
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      },
    ];

    // First, create Firebase Auth users with password "abc123"
    for (var user in users) {
      try {
        final email = user['email'] as String;
        
        debugPrint('Creating Firebase Auth user for: $email');
        
        // Create user in Firebase Auth with password "abc123"
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: 'abc123',
        );
        
        debugPrint('✅ Created Firebase Auth user: ${userCredential.user?.uid}');
        
      } catch (e) {
        // If user already exists, that's fine - continue with Firestore document
        debugPrint('⚠️ User ${user['email']} might already exist in Firebase Auth: $e');
      }
    }

    // Then create Firestore documents using our custom UIDs
    final batch = _db.batch();
    for (var user in users) {
      final ref = _db.collection('users').doc(user['uid'] as String);
      batch.set(ref, {
        ...user,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('✅ Users seeded with password "abc123" for all accounts');
  }

  /// Seed sessions data with comprehensive information
  static Future<void> _seedSessions(String eventId) async {
    debugPrint('📅 Seeding sessions...');
    
    final sessions = [
      // Day 1 - November 15, 2024
      {
        'eventId': eventId,
        'title': 'Building Scalable Flutter Apps with Advanced State Management',
        'description': 'Deep dive into Riverpod, Bloc, and custom state management solutions. Learn how to architect large-scale Flutter applications with proper separation of concerns, dependency injection, and reactive programming patterns.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 15, 9, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 15, 10, 30)),
        'location': 'Main Auditorium',
        'room': 'Hall A',
        'capacity': 500,
        'registeredAttendees': 347,
        'speakerIds': ['speaker_001', 'speaker_002'],
        'type': 'keynote',
        'level': 'intermediate',
        'tags': ['flutter', 'state-management', 'architecture', 'riverpod', 'bloc'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://speakerdeck.com/sarahchen/scalable-flutter-apps',
        'recordingUrl': '',
        'materials': ['Code samples', 'Architecture diagrams', 'Best practices guide'],
        'prerequisites': ['Basic Flutter knowledge', 'Understanding of OOP concepts'],
        'learningObjectives': [
          'Master advanced state management patterns',
          'Implement clean architecture in Flutter',
          'Handle complex app state effectively'
        ],
      },
      {
        'eventId': eventId,
        'title': 'Cloud-Native Mobile Development with Firebase',
        'description': 'Learn how to build powerful mobile applications using Firebase services including Authentication, Firestore, Cloud Functions, and more. Real-world examples and best practices included.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 15, 11, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 15, 12, 0)),
        'location': 'Conference Room B',
        'room': 'Room B-201',
        'capacity': 150,
        'registeredAttendees': 142,
        'speakerIds': ['speaker_004'],
        'type': 'talk',
        'level': 'beginner',
        'tags': ['firebase', 'cloud', 'backend', 'authentication', 'database'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://slides.com/davidkim/firebase-mobile',
        'recordingUrl': '',
        'materials': ['Firebase setup guide', 'Sample project', 'Security rules examples'],
        'prerequisites': ['Basic mobile development experience'],
        'learningObjectives': [
          'Set up Firebase for mobile apps',
          'Implement user authentication',
          'Design scalable database schemas'
        ],
      },
      {
        'eventId': eventId,
        'title': 'Design Systems for Flutter: Creating Consistent UIs',
        'description': 'Building and maintaining design systems in Flutter applications. Learn how to create reusable components, establish design tokens, and ensure consistency across your app.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 15, 13, 30)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 15, 14, 30)),
        'location': 'Workshop Space 1',
        'room': 'Workshop A',
        'capacity': 80,
        'registeredAttendees': 75,
        'speakerIds': ['speaker_003'],
        'type': 'workshop',
        'level': 'intermediate',
        'tags': ['design-systems', 'ui', 'flutter', 'theming', 'components'],
        'liveStreamUrl': '',
        'slidesUrl': 'https://figma.com/presentation/design-systems-flutter',
        'recordingUrl': '',
        'materials': ['Design system template', 'Component library', 'Style guide'],
        'prerequisites': ['Flutter UI development experience', 'Basic design knowledge'],
        'learningObjectives': [
          'Create scalable design systems',
          'Build reusable UI components',
          'Implement consistent theming'
        ],
      },
      {
        'eventId': eventId,
        'title': 'Performance Optimization in Flutter Applications',
        'description': 'Techniques for optimizing Flutter app performance including widget optimization, memory management, and profiling tools. Learn to build apps that perform smoothly on all devices.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 15, 15, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 15, 16, 0)),
        'location': 'Main Auditorium',
        'room': 'Hall A',
        'capacity': 500,
        'registeredAttendees': 289,
        'speakerIds': ['speaker_002'],
        'type': 'talk',
        'level': 'advanced',
        'tags': ['performance', 'optimization', 'profiling', 'memory', 'flutter'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://speakerdeck.com/alexmartinez/flutter-performance',
        'recordingUrl': '',
        'materials': ['Performance checklist', 'Profiling tools guide', 'Optimization examples'],
        'prerequisites': ['Advanced Flutter knowledge', 'Experience with app development'],
        'learningObjectives': [
          'Identify performance bottlenecks',
          'Optimize widget rendering',
          'Manage memory efficiently'
        ],
      },

      // Day 2 - November 16, 2024
      {
        'eventId': eventId,
        'title': 'Building Serverless Mobile Backends with AWS',
        'description': 'Create scalable, cost-effective mobile backends using AWS Lambda, API Gateway, and other serverless services. Hands-on workshop with real deployment examples.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 16, 9, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 16, 10, 30)),
        'location': 'Workshop Space 2',
        'room': 'Workshop B',
        'capacity': 100,
        'registeredAttendees': 94,
        'speakerIds': ['speaker_006'],
        'type': 'workshop',
        'level': 'intermediate',
        'tags': ['aws', 'serverless', 'lambda', 'api-gateway', 'backend'],
        'liveStreamUrl': '',
        'slidesUrl': 'https://slides.aws.com/serverless-mobile',
        'recordingUrl': '',
        'materials': ['AWS setup guide', 'Serverless templates', 'Cost optimization tips'],
        'prerequisites': ['Basic cloud knowledge', 'API development experience'],
        'learningObjectives': [
          'Design serverless architectures',
          'Deploy AWS Lambda functions',
          'Optimize costs and performance'
        ],
      },
      {
        'eventId': eventId,
        'title': 'Advanced Flutter Testing Strategies',
        'description': 'Comprehensive testing approaches for Flutter applications including unit tests, widget tests, integration tests, and golden tests. Learn to build reliable, maintainable test suites.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 16, 11, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 16, 12, 0)),
        'location': 'Conference Room C',
        'room': 'Room C-301',
        'capacity': 120,
        'registeredAttendees': 98,
        'speakerIds': ['speaker_001'],
        'type': 'talk',
        'level': 'intermediate',
        'tags': ['testing', 'flutter', 'quality-assurance', 'automation', 'tdd'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://speakerdeck.com/sarahchen/flutter-testing',
        'recordingUrl': '',
        'materials': ['Testing framework guide', 'Test examples', 'CI/CD templates'],
        'prerequisites': ['Flutter development experience', 'Basic testing knowledge'],
        'learningObjectives': [
          'Implement comprehensive test strategies',
          'Set up automated testing pipelines',
          'Ensure code quality and reliability'
        ],
      },
      {
        'eventId': eventId,
        'title': 'The Future of Immersive Experiences: VR/AR in Mobile Apps',
        'description': 'Explore the cutting-edge world of VR/AR development for mobile platforms. Learn about ARCore, ARKit integration and building immersive experiences with Flutter.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 16, 13, 30)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 16, 14, 30)),
        'location': 'Innovation Lab',
        'room': 'Lab 1',
        'capacity': 60,
        'registeredAttendees': 56,
        'speakerIds': ['speaker_005'],
        'type': 'demo',
        'level': 'advanced',
        'tags': ['vr', 'ar', 'immersive', 'arcore', 'arkit', 'future-tech'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://slides.com/rebeccatorres/vr-ar-mobile',
        'recordingUrl': '',
        'materials': ['AR development kit', 'Sample AR projects', 'Hardware requirements'],
        'prerequisites': ['3D graphics knowledge', 'Advanced mobile development'],
        'learningObjectives': [
          'Understand AR/VR fundamentals',
          'Integrate AR features in mobile apps',
          'Explore future possibilities'
        ],
      },
      {
        'eventId': eventId,
        'title': 'Cross-Platform Development: Flutter vs React Native',
        'description': 'Comparative analysis of Flutter and React Native for cross-platform development. When to choose which framework and migration strategies.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 16, 15, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 16, 16, 0)),
        'location': 'Conference Room D',
        'room': 'Room D-401',
        'capacity': 200,
        'registeredAttendees': 178,
        'speakerIds': ['speaker_003', 'speaker_004'],
        'type': 'panel',
        'level': 'beginner',
        'tags': ['cross-platform', 'flutter', 'react-native', 'comparison', 'migration'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://slides.com/comparison-flutter-rn',
        'recordingUrl': '',
        'materials': ['Framework comparison guide', 'Migration checklist', 'Decision matrix'],
        'prerequisites': ['Basic mobile development knowledge'],
        'learningObjectives': [
          'Compare cross-platform frameworks',
          'Make informed technology decisions',
          'Plan migration strategies'
        ],
      },

      // Day 3 - November 17, 2024
      {
        'eventId': eventId,
        'title': 'AI-Powered Mobile Applications: Machine Learning in Flutter',
        'description': 'Integrate machine learning capabilities into Flutter apps using TensorFlow Lite, MLKit, and custom models. Build intelligent, responsive mobile experiences.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 17, 9, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 17, 10, 30)),
        'location': 'AI Lab',
        'room': 'Lab 2',
        'capacity': 80,
        'registeredAttendees': 77,
        'speakerIds': ['speaker_002', 'speaker_006'],
        'type': 'workshop',
        'level': 'advanced',
        'tags': ['ai', 'machine-learning', 'tensorflow', 'mlkit', 'flutter'],
        'liveStreamUrl': '',
        'slidesUrl': 'https://slides.com/ai-flutter-workshop',
        'recordingUrl': '',
        'materials': ['ML model examples', 'TensorFlow Lite guide', 'AI integration patterns'],
        'prerequisites': ['Flutter experience', 'Basic ML knowledge', 'Python familiarity'],
        'learningObjectives': [
          'Integrate ML models in Flutter',
          'Optimize models for mobile',
          'Build AI-powered features'
        ],
      },
      {
        'eventId': eventId,
        'title': 'DevOps for Mobile: CI/CD Pipelines and Automation',
        'description': 'Streamline your mobile development workflow with automated testing, building, and deployment pipelines. Tools, best practices, and real-world implementations.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 17, 11, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 17, 12, 0)),
        'location': 'Conference Room E',
        'room': 'Room E-501',
        'capacity': 150,
        'registeredAttendees': 134,
        'speakerIds': ['speaker_004'],
        'type': 'talk',
        'level': 'intermediate',
        'tags': ['devops', 'ci-cd', 'automation', 'deployment', 'testing'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://slides.com/davidkim/mobile-devops',
        'recordingUrl': '',
        'materials': ['CI/CD templates', 'Automation scripts', 'Deployment guides'],
        'prerequisites': ['Development experience', 'Git knowledge', 'Basic DevOps concepts'],
        'learningObjectives': [
          'Set up automated pipelines',
          'Implement continuous deployment',
          'Optimize development workflow'
        ],
      },
      {
        'eventId': eventId,
        'title': 'Building Accessible Mobile Applications',
        'description': 'Create inclusive mobile experiences by implementing proper accessibility features. Learn about screen readers, voice control, and universal design principles.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 17, 13, 30)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 17, 14, 30)),
        'location': 'Accessibility Lab',
        'room': 'Lab 3',
        'capacity': 70,
        'registeredAttendees': 63,
        'speakerIds': ['speaker_003'],
        'type': 'workshop',
        'level': 'beginner',
        'tags': ['accessibility', 'inclusive-design', 'usability', 'wcag', 'screen-reader'],
        'liveStreamUrl': '',
        'slidesUrl': 'https://slides.com/maya/accessibility-mobile',
        'recordingUrl': '',
        'materials': ['Accessibility checklist', 'Testing tools', 'Design guidelines'],
        'prerequisites': ['UI development experience', 'Basic design knowledge'],
        'learningObjectives': [
          'Implement accessibility features',
          'Test for accessibility compliance',
          'Design inclusive interfaces'
        ],
      },
      {
        'eventId': eventId,
        'title': 'Scaling Mobile Apps: Architecture and Performance at Scale',
        'description': 'Learn how to architect mobile applications that can scale to millions of users. Database optimization, caching strategies, and performance monitoring.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 17, 15, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 17, 16, 30)),
        'location': 'Main Auditorium',
        'room': 'Hall A',
        'capacity': 500,
        'registeredAttendees': 423,
        'speakerIds': ['speaker_001', 'speaker_004', 'speaker_006'],
        'type': 'keynote',
        'level': 'advanced',
        'tags': ['scaling', 'architecture', 'performance', 'database', 'monitoring'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://speakerdeck.com/scaling-mobile-apps',
        'recordingUrl': '',
        'materials': ['Architecture patterns', 'Scaling checklist', 'Monitoring tools guide'],
        'prerequisites': ['Advanced development experience', 'System design knowledge'],
        'learningObjectives': [
          'Design scalable architectures',
          'Implement performance monitoring',
          'Optimize for high traffic'
        ],
      },
      {
        'eventId': eventId,
        'title': 'The Future of Mobile Development: Trends and Predictions',
        'description': 'Closing keynote exploring emerging trends in mobile development including Web3, IoT integration, edge computing, and the next generation of mobile platforms.',
        'startTime': Timestamp.fromDate(DateTime(2024, 11, 17, 17, 0)),
        'endTime': Timestamp.fromDate(DateTime(2024, 11, 17, 18, 0)),
        'location': 'Main Auditorium',
        'room': 'Hall A',
        'capacity': 500,
        'registeredAttendees': 456,
        'speakerIds': ['speaker_002', 'speaker_005'],
        'type': 'keynote',
        'level': 'all',
        'tags': ['future', 'trends', 'web3', 'iot', 'edge-computing', 'innovation'],
        'liveStreamUrl': 'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'slidesUrl': 'https://slides.com/future-mobile-dev',
        'recordingUrl': '',
        'materials': ['Trend analysis report', 'Technology roadmap', 'Innovation predictions'],
        'prerequisites': ['General mobile development interest'],
        'learningObjectives': [
          'Understand emerging trends',
          'Prepare for future technologies',
          'Plan technology adoption strategies'
        ],
      },
    ];

    final batch = _db.batch();
    for (int i = 0; i < sessions.length; i++) {
      final ref = _db.collection('sessions').doc('session_${(i + 1).toString().padLeft(3, '0')}');
      batch.set(ref, {
        ...sessions[i],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('✅ Sessions seeded');
  }
}