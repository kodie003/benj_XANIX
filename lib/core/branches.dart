import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

/// An owner's branches and warehouses, live. Each is a shop of its own (shops/{uid})
/// that names the owner as its main shop, so the owner can open it and log for it.
class BranchList extends ChangeNotifier {
  BranchList(this.owner) {
    _sub = FirebaseFirestore.instance.collection('shops').where('mainShop', isEqualTo: owner).snapshots().listen((q) {
      branches = [for (final d in q.docs) Branch(uid: d.id, name: (d.data()['name'] as String?) ?? '')]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      loaded = true;
      notifyListeners();
    }, onError: (Object e) {
      if (e is FirebaseException && e.code == 'permission-denied') return; // signing out
      debugPrint('benj: branch list error: $e');
    });
  }

  final String owner;
  late final StreamSubscription _sub;
  List<Branch> branches = [];
  bool loaded = false;

  Branch? byId(String uid) => branches.where((b) => b.uid == uid).firstOrNull;

  /// Same name ignoring capitals and spaces, as the service checks it.
  bool nameTaken(String name, {String? except}) {
    String n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return branches.any((b) => b.uid != except && n(b.name) == n(name));
  }

  /// After the owner renames their shop, branches show the new name.
  Future<void> renameMain(String mainName) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final b in branches) {
      batch.update(FirebaseFirestore.instance.collection('shops').doc(b.uid), {'mainName': mainName});
    }
    try {
      await batch.commit().timeout(const Duration(milliseconds: 1400));
    } on TimeoutException {
      // Queued; it will sync.
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
