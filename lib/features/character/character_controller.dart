import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/kv_repo.dart';
import '../../domain/models.dart';

/// Edits the character's name and display title.
class CharacterController {
  CharacterController(this._kv);

  final KvRepo _kv;

  Future<Character> _current() async =>
      await _kv.character() ?? const Character(name: '');

  Future<void> setName(String name) async {
    final c = await _current();
    await _kv.saveCharacter(c.copyWith(name: name.trim()));
  }

  /// Shows the title of [level] in [skillId] (a reached `LevelReached` row).
  Future<void> setTitle(String skillId, int level) async {
    final c = await _current();
    await _kv.saveCharacter(
      c.copyWith(titleSkillId: skillId, titleLevel: level),
    );
  }

  /// Back to the default: the title of the highest-level skill.
  Future<void> clearTitle() async {
    final c = await _current();
    await _kv.saveCharacter(c.copyWith(titleSkillId: null, titleLevel: null));
  }
}

final characterControllerProvider = Provider<CharacterController>(
  (ref) => CharacterController(KvRepo(ref.watch(dbProvider))),
);
