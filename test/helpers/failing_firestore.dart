import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

/// Mocktail mocks για να προσομοιωθούν Firestore σφάλματα (write/read).
/// Χρησιμοποιούνται ΜΟΝΟ στα error-path tests — τα happy paths χρησιμοποιούν
/// `FakeFirebaseFirestore`.
class MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocument extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

/// [SPoT] Επιστρέφει ένα `FirebaseFirestore` του οποίου κάθε write σε
/// `users/{uid}/blocked/{blockedUid}` αποτυγχάνει — για τον έλεγχο του
/// non-fatal handshake στο `BlockRepositoryImpl`.
MockFirestore failingBlockWriteFirestore({
  String uid = 'me',
  String blockedUid = 'them',
}) {
  final fs = MockFirestore();
  final users = MockCollection();
  final userDoc = MockDocument();
  final blocked = MockCollection();
  final leaf = MockDocument();

  when(() => fs.collection('users')).thenReturn(users);
  when(() => users.doc(uid)).thenReturn(userDoc);
  when(() => userDoc.collection('blocked')).thenReturn(blocked);
  when(() => blocked.doc(blockedUid)).thenReturn(leaf);
  when(() => leaf.set(any(), any())).thenThrow(Exception('sync failure'));
  when(() => leaf.delete()).thenThrow(Exception('sync failure'));
  return fs;
}

/// [SPoT] Επιστρέφει ένα `FirebaseFirestore` του οποίου το `add` στη
/// `reports` collection αποτυγχάνει — για το error-path του
/// `ReportRepositoryImpl`.
MockFirestore failingReportFirestore() {
  final fs = MockFirestore();
  final reports = MockCollection();
  when(() => fs.collection('reports')).thenReturn(reports);
  when(() => reports.add(any())).thenThrow(Exception('write failure'));
  return fs;
}

/// [SPoT] Επιστρέφει ένα `FirebaseFirestore` του οποίου το `set` στο
/// `groups/{chatId}` αποτυγχάνει — για το error-path του
/// `FirestoreGroupSearchRepository.createPublicProfile`.
MockFirestore failingGroupWriteFirestore({String chatId = 'g_new'}) {
  final fs = MockFirestore();
  final groups = MockCollection();
  final doc = MockDocument();
  when(() => fs.collection('groups')).thenReturn(groups);
  when(() => groups.doc(chatId)).thenReturn(doc);
  when(() => doc.set(any())).thenThrow(Exception('write failure'));
  return fs;
}

/// [SPoT] Επιστρέφει ένα `FirebaseFirestore` του οποίου η `requests`
/// collection αποτυγχάνει στα write/read paths — για τα error-paths του
/// `RequestRepositoryImpl`. Τα reads (doc.get / query) αφήνονται χωρίς stub:
/// το MissingStubError που ρίχνει το mocktail πιάνεται από τα repo catch.
MockFirestore failingRequestsFirestore() {
  final fs = MockFirestore();
  final requests = MockCollection();
  when(() => fs.collection('requests')).thenReturn(requests);
  when(() => requests.add(any())).thenThrow(Exception('write failure'));
  return fs;
}
