import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/session.dart';
import 'list_store.dart';

/// Edits only go through while the list syncs to AniList; otherwise they'd
/// look saved and quietly vanish. Signed out, they lead to Log In instead;
/// while the account is still loading or unreachable, they wait.
bool canEditList(BuildContext context, WidgetRef ref) {
  if (ref.read(listStoreProvider.notifier).sync) return true;
  if (ref.read(sessionProvider).authState == AuthState.signedOut) context.push('/login');
  return false;
}
