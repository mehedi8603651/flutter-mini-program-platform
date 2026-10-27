import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../models.dart';

/// Parse Dart instead of rewriting constructors with regular expressions.
/// Existing router configuration, builder behavior and navigation keys survive.
Future<Map<String, String>> planHostAiBuilder({
  required String projectRootPath,
  required Map<String, String> pendingWrites,
}) async {
  final lib = Directory(p.join(projectRootPath, 'lib'));
  final integration = p.join(lib.path, 'mini_program');
  final candidates = <_AppConstructor>[];
  final files = await lib
      .list(recursive: true, followLinks: false)
      .where(
        (entity) =>
            entity is File &&
            entity.path.endsWith('.dart') &&
            !p.isWithin(integration, entity.path) &&
            !entity.path.endsWith('.g.dart') &&
            !entity.path.endsWith('.freezed.dart'),
      )
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final source = pendingWrites[file.path] ?? await file.readAsString();
    final parsed = parseString(
      content: source,
      path: file.path,
      throwIfDiagnostics: false,
    );
    final visitor = _AppVisitor(file.path, source, parsed.unit);
    parsed.unit.accept(visitor);
    if (visitor.apps.isNotEmpty && parsed.errors.isNotEmpty) {
      throw MiniProgramEmbeddingInitException(
        'Cannot safely install --ai-assistant in ${file.path}: repair Dart syntax first.',
      );
    }
    candidates.addAll(visitor.apps);
  }
  final installed = candidates.where((app) => app.installed).toList();
  final selected = installed.isNotEmpty ? installed : candidates;
  if (selected.length != 1) {
    throw MiniProgramEmbeddingInitException(
      '--ai-assistant needs one MaterialApp or MaterialApp.router root under lib/; '
      'found ${selected.length}. For multiple app roots, set the intended root\'s '
      'builder to mini_program_ai.buildHostAiOverlay and import '
      'mini_program/mini_program_ai.dart as mini_program_ai, then retry. '
      'No files were changed.',
    );
  }
  final app = selected.single;
  if (app.unit.directives.any((directive) => directive is PartOfDirective)) {
    throw const MiniProgramEmbeddingInitException(
      '--ai-assistant cannot add imports to a part-of library. Move the app root '
      'to a normal Dart library before retrying. No files were changed.',
    );
  }
  final relative = p
      .relative(
        p.join(integration, 'mini_program_ai.dart'),
        from: p.dirname(app.path),
      )
      .replaceAll('\\', '/');
  final expectedImport = "import '$relative' as mini_program_ai;";
  final existingImport = app.unit.directives
      .whereType<ImportDirective>()
      .where((directive) => directive.prefix?.name == 'mini_program_ai')
      .toList();
  if (existingImport.length > 1 ||
      (existingImport.isNotEmpty &&
          existingImport.single.uri.stringValue != relative)) {
    throw const MiniProgramEmbeddingInitException(
      'The mini_program_ai import prefix is already used by another library. '
      'Reconcile it before installing --ai-assistant.',
    );
  }
  var source = app.source;
  if (!app.installed) {
    final builder = app.builder;
    if (builder == null) {
      source = source.replaceRange(
        app.arguments.leftParenthesis.end,
        app.arguments.leftParenthesis.end,
        '\n      builder: mini_program_ai.buildHostAiOverlay,',
      );
    } else {
      AstNode? declaration = app.node.parent;
      while (declaration != null) {
        if (declaration is VariableDeclarationList && declaration.isConst) {
          throw const MiniProgramEmbeddingInitException(
            '--ai-assistant cannot compose a builder inside a const variable. '
            'Make the root app value final before retrying. No files were changed.',
          );
        }
        declaration = declaration.parent;
      }
      final expression = builder.expression;
      source = source.replaceRange(
        expression.offset,
        expression.end,
        'mini_program_ai.composeHostAiBuilder(${app.source.substring(expression.offset, expression.end)})',
      );
      // Composing an existing builder is a runtime expression. Remove only
      // explicit const keywords governing that expression, preserving its value.
      final keywords = <int>[];
      AstNode? ancestor = app.node;
      while (ancestor != null) {
        if (ancestor is InstanceCreationExpression &&
            ancestor.keyword?.lexeme == 'const') {
          keywords.add(ancestor.keyword!.offset);
        }
        ancestor = ancestor.parent;
      }
      keywords.sort((a, b) => b.compareTo(a));
      for (final offset in keywords) {
        source = source.replaceRange(offset, offset + 5, '');
      }
    }
  }
  if (existingImport.isEmpty) {
    final library = app.unit.directives
        .whereType<LibraryDirective>()
        .firstOrNull;
    final offset =
        library?.end ??
        (source.startsWith('#!') ? source.indexOf('\n') + 1 : 0);
    source = source.replaceRange(
      offset,
      offset,
      '${offset == 0 ? '' : '\n'}$expectedImport\n',
    );
  }
  return {app.path: source};
}

class _AppConstructor {
  _AppConstructor(this.path, this.source, this.unit, this.node, this.arguments);
  final String path;
  final String source;
  final CompilationUnit unit;
  final Expression node;
  final ArgumentList arguments;
  NamedExpression? get builder => arguments.arguments
      .whereType<NamedExpression>()
      .where((arg) => arg.name.label.name == 'builder')
      .firstOrNull;
  bool get installed =>
      builder?.expression.toSource() == 'mini_program_ai.buildHostAiOverlay' ||
      builder?.expression.toSource().startsWith(
            'mini_program_ai.composeHostAiBuilder(',
          ) ==
          true;
}

class _AppVisitor extends RecursiveAstVisitor<void> {
  _AppVisitor(this.path, this.source, this.unit);
  final String path;
  final String source;
  final CompilationUnit unit;
  final apps = <_AppConstructor>[];
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.toSource().split('.').last == 'MaterialApp' &&
        (node.constructorName.name == null ||
            node.constructorName.name?.name == 'router')) {
      apps.add(_AppConstructor(path, source, unit, node, node.argumentList));
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Unresolved parsing represents constructors without new/const as method
    // invocations. Resolution is unnecessary for these bounded source edits.
    if (node.methodName.name == 'MaterialApp' ||
        (node.methodName.name == 'router' &&
            node.target?.toSource().split('.').last == 'MaterialApp')) {
      apps.add(_AppConstructor(path, source, unit, node, node.argumentList));
    }
    super.visitMethodInvocation(node);
  }
}
