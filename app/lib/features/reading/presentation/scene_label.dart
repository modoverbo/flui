import 'package:flui/core/l10n/l10n.dart';
import 'package:flui/features/reading/domain/reading.dart';

String sceneLabel(AppLocalizations l10n, Scene scene) => switch (scene) {
  Scene.trabajo => l10n.sceneTrabajo,
  Scene.social => l10n.sceneSocial,
  Scene.entrevista => l10n.sceneEntrevista,
  Scene.familia => l10n.sceneFamilia,
};
