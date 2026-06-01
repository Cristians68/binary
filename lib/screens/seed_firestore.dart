import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSeeder {
  static final _db = FirebaseFirestore.instance;

  static Future<void> seedAll() async {
    await _seedITILV4();
    await _seedCSM();
    await _seedNetworking();
    print('✅ Seeding complete!');
  }

  static Future<void> _seedITILV4() async {
    final courseRef = _db.collection('courses').doc('itil-v4');

    await courseRef.set({
      'title': 'ITIL V4 Foundation',
      'subtitle': 'Service management basics',
      'tag': 'ITIL V4',
      'color': 0xFF6366F1,
      'icon': 'doc_text',
      'order': 1,
      'isComingSoon': false,
    });

    final modules = [
      {
        'id': 'module-1',
        'title': 'What is ITIL?',
        'subtitle': '5 flashcards · quiz',
        'order': 1,
        'status': 'active',
      },
      {
        'id': 'module-2',
        'title': 'Key Concepts',
        'subtitle': '6 flashcards · quiz',
        'order': 2,
        'status': 'locked',
      },
      {
        'id': 'module-3',
        'title': 'Service Value System',
        'subtitle': '8 flashcards · quiz',
        'order': 3,
        'status': 'locked',
      },
      {
        'id': 'module-4',
        'title': '4 Dimensions Model',
        'subtitle': '5 flashcards · quiz',
        'order': 4,
        'status': 'locked',
      },
      {
        'id': 'module-5',
        'title': 'Guiding Principles',
        'subtitle': '7 flashcards · quiz',
        'order': 5,
        'status': 'locked',
      },
      {
        'id': 'module-6',
        'title': 'Practices Overview',
        'subtitle': '6 flashcards · quiz',
        'order': 6,
        'status': 'locked',
      },
      {
        'id': 'module-7',
        'title': 'Final Quiz',
        'subtitle': '20 questions',
        'order': 7,
        'status': 'locked',
      },
    ];

    for (final module in modules) {
      final moduleRef = courseRef
          .collection('modules')
          .doc(module['id'] as String);
      await moduleRef.set(module);

      if (module['id'] == 'module-1') {
        await _seedITILModule1Flashcards(moduleRef);
        await _seedITILModule1Quiz(moduleRef);
      }
    }
  }

  static Future<void> _seedITILModule1Flashcards(
      DocumentReference moduleRef) async {
    final flashcards = [
      {
        'order': 1,
        'question': 'What does ITIL stand for?',
        'answer':
            'Information Technology Infrastructure Library — a framework of best practices for delivering IT services.',
      },
      {
        'order': 2,
        'question': 'What is the main purpose of ITIL?',
        'answer':
            'To align IT services with the needs of the business by providing a structured approach to service management.',
      },
      {
        'order': 3,
        'question': 'Which organisation owns and maintains ITIL?',
        'answer':
            'AXELOS, a joint venture that manages best practice frameworks including ITIL and PRINCE2.',
      },
      {
        'order': 4,
        'question': 'What version of ITIL is currently in use?',
        'answer':
            'ITIL 4, released in 2019. It introduced the Service Value System and a more flexible, holistic approach.',
      },
      {
        'order': 5,
        'question': 'What is a service in ITIL terms?',
        'answer':
            'A means of enabling value co-creation by facilitating outcomes that customers want to achieve, without managing specific costs and risks.',
      },
    ];

    for (final card in flashcards) {
      await moduleRef.collection('flashcards').add(card);
    }
  }

  static Future<void> _seedITILModule1Quiz(
      DocumentReference moduleRef) async {
    final questions = [
      {
        'order': 1,
        'question': 'What does ITIL stand for?',
        'options': [
          'Information Technology Infrastructure Library',
          'Integrated Technology Implementation Layer',
          'Internal Tool Integration Lifecycle',
          'IT Infrastructure and Logistics',
        ],
        'correctIndex': 0,
        'explanation':
            'ITIL stands for Information Technology Infrastructure Library.',
      },
      {
        'order': 2,
        'question': 'Who owns ITIL?',
        'options': [
          'Microsoft',
          'AXELOS',
          'ISO',
          'The Open Group',
        ],
        'correctIndex': 1,
        'explanation':
            'AXELOS owns and maintains ITIL along with other best practice frameworks.',
      },
      {
        'order': 3,
        'question': 'What year was ITIL 4 released?',
        'options': [
          '2011',
          '2015',
          '2019',
          '2021',
        ],
        'correctIndex': 2,
        'explanation':
            'ITIL 4 was released in February 2019, replacing ITIL v3.',
      },
      {
        'order': 4,
        'question': 'What is the primary goal of ITIL?',
        'options': [
          'To reduce IT staff headcount',
          'To align IT services with business needs',
          'To replace agile methodologies',
          'To standardise hardware procurement',
        ],
        'correctIndex': 1,
        'explanation':
            'ITIL aims to align IT services with business needs through structured best practices.',
      },
      {
        'order': 5,
        'question': 'Which concept is central to ITIL 4?',
        'options': [
          'Service Desk',
          'Change Advisory Board',
          'Service Value System',
          'Configuration Management Database',
        ],
        'correctIndex': 2,
        'explanation':
            'The Service Value System (SVS) is the central concept of ITIL 4.',
      },
    ];

    for (final q in questions) {
      await moduleRef.collection('quiz').add(q);
    }
  }

  static Future<void> _seedCSM() async {
    final courseRef = _db.collection('courses').doc('csm');

    await courseRef.set({
      'title': 'CSM Fundamentals',
      'subtitle': 'Scrum & agile methods',
      'tag': 'CSM',
      'color': 0xFF10B981,
      'icon': 'person_2',
      'order': 2,
      'isComingSoon': false,
    });

    final modules = [
      {
        'id': 'module-1',
        'title': 'What is Scrum?',
        'subtitle': '5 flashcards · quiz',
        'order': 1,
        'status': 'active',
      },
      {
        'id': 'module-2',
        'title': 'The Scrum Team',
        'subtitle': '6 flashcards · quiz',
        'order': 2,
        'status': 'locked',
      },
      {
        'id': 'module-3',
        'title': 'Scrum Events',
        'subtitle': '5 flashcards · quiz',
        'order': 3,
        'status': 'locked',
      },
      {
        'id': 'module-4',
        'title': 'Scrum Artifacts',
        'subtitle': '4 flashcards · quiz',
        'order': 4,
        'status': 'locked',
      },
      {
        'id': 'module-5',
        'title': 'Definition of Done',
        'subtitle': '3 flashcards · quiz',
        'order': 5,
        'status': 'locked',
      },
      {
        'id': 'module-6',
        'title': 'Final Quiz',
        'subtitle': '20 questions',
        'order': 6,
        'status': 'locked',
      },
    ];

    for (final module in modules) {
      await courseRef
          .collection('modules')
          .doc(module['id'] as String)
          .set(module);
    }
  }

  static Future<void> _seedNetworking() async {
    final courseRef = _db.collection('courses').doc('networking');

    await courseRef.set({
      'title': 'Networking Basics',
      'subtitle': 'TCP/IP, DNS, subnets',
      'tag': 'Networking',
      'color': 0xFFF59E0B,
      'icon': 'antenna',
      'order': 3,
      'isComingSoon': false,
    });

    final modules = [
      {
        'id': 'module-1',
        'title': 'What is a Network?',
        'subtitle': '5 flashcards · quiz',
        'order': 1,
        'status': 'active',
      },
      {
        'id': 'module-2',
        'title': 'IP Addresses',
        'subtitle': '6 flashcards · quiz',
        'order': 2,
        'status': 'locked',
      },
      {
        'id': 'module-3',
        'title': 'DNS & Routing',
        'subtitle': '5 flashcards · quiz',
        'order': 3,
        'status': 'locked',
      },
      {
        'id': 'module-4',
        'title': 'TCP/IP Deep Dive',
        'subtitle': '7 flashcards · quiz',
        'order': 4,
        'status': 'locked',
      },
      {
        'id': 'module-5',
        'title': 'Subnetting',
        'subtitle': '6 flashcards · quiz',
        'order': 5,
        'status': 'locked',
      },
      {
        'id': 'module-6',
        'title': 'Network Security',
        'subtitle': '5 flashcards · quiz',
        'order': 6,
        'status': 'locked',
      },
      {
        'id': 'module-7',
        'title': 'Final Quiz',
        'subtitle': '20 questions',
        'order': 7,
        'status': 'locked',
      },
    ];

    for (final module in modules) {
      await courseRef
          .collection('modules')
          .doc(module['id'] as String)
          .set(module);
    }
  }
}