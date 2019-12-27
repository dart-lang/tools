// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:source_span/source_span.dart';
import 'parser.dart';

part 'src/css_printer.dart';
part 'src/tree.dart';
part 'src/tree_base.dart';
part 'src/tree_printer.dart';

abstract class VisitorBase {
  visitCalcTerm(CalcTerm node);
  visitCssComment(CssComment node);
  visitCommentDefinition(CommentDefinition node);
  visitStyleSheet(StyleSheet node);
  visitNoOp(NoOp node);
  visitTopLevelProduction(TopLevelProduction node);
  visitDirective(Directive node);
  visitDocumentDirective(DocumentDirective node);
  visitSupportsDirective(SupportsDirective node);
  visitSupportsConditionInParens(SupportsConditionInParens node);
  visitSupportsNegation(SupportsNegation node);
  visitSupportsConjunction(SupportsConjunction node);
  visitSupportsDisjunction(SupportsDisjunction node);
  visitViewportDirective(ViewportDirective node);
  visitMediaExpression(MediaExpression node);
  visitMediaQuery(MediaQuery node);
  visitMediaDirective(MediaDirective node);
  visitHostDirective(HostDirective node);
  visitPageDirective(PageDirective node);
  visitCharsetDirective(CharsetDirective node);
  visitImportDirective(ImportDirective node);
  visitKeyFrameDirective(KeyFrameDirective node);
  visitKeyFrameBlock(KeyFrameBlock node);
  visitFontFaceDirective(FontFaceDirective node);
  visitStyletDirective(StyletDirective node);
  visitNamespaceDirective(NamespaceDirective node);
  visitVarDefinitionDirective(VarDefinitionDirective node);
  visitMixinDefinition(MixinDefinition node);
  visitMixinRulesetDirective(MixinRulesetDirective node);
  visitMixinDeclarationDirective(MixinDeclarationDirective node);
  visitIncludeDirective(IncludeDirective node);
  visitContentDirective(ContentDirective node);

  visitRuleSet(RuleSet node);
  visitDeclarationGroup(DeclarationGroup node);
  visitMarginGroup(MarginGroup node);
  visitDeclaration(Declaration node);
  visitVarDefinition(VarDefinition node);
  visitIncludeMixinAtDeclaration(IncludeMixinAtDeclaration node);
  visitExtendDeclaration(ExtendDeclaration node);
  visitSelectorGroup(SelectorGroup node);
  visitSelector(Selector node);
  visitSimpleSelectorSequence(SimpleSelectorSequence node);
  visitSimpleSelector(SimpleSelector node);
  visitElementSelector(ElementSelector node);
  visitNamespaceSelector(NamespaceSelector node);
  visitAttributeSelector(AttributeSelector node);
  visitIdSelector(IdSelector node);
  visitClassSelector(ClassSelector node);
  visitPseudoClassSelector(PseudoClassSelector node);
  visitPseudoElementSelector(PseudoElementSelector node);
  visitPseudoClassFunctionSelector(PseudoClassFunctionSelector node);
  visitPseudoElementFunctionSelector(PseudoElementFunctionSelector node);
  visitNegationSelector(NegationSelector node);
  visitSelectorExpression(SelectorExpression node);

  visitUnicodeRangeTerm(UnicodeRangeTerm node);
  visitLiteralTerm(LiteralTerm node);
  visitHexColorTerm(HexColorTerm node);
  visitNumberTerm(NumberTerm node);
  visitUnitTerm(UnitTerm node);
  visitLengthTerm(LengthTerm node);
  visitPercentageTerm(PercentageTerm node);
  visitEmTerm(EmTerm node);
  visitExTerm(ExTerm node);
  visitAngleTerm(AngleTerm node);
  visitTimeTerm(TimeTerm node);
  visitFreqTerm(FreqTerm node);
  visitFractionTerm(FractionTerm node);
  visitUriTerm(UriTerm node);
  visitResolutionTerm(ResolutionTerm node);
  visitChTerm(ChTerm node);
  visitRemTerm(RemTerm node);
  visitViewportTerm(ViewportTerm node);
  visitFunctionTerm(FunctionTerm node);
  visitGroupTerm(GroupTerm node);
  visitItemTerm(ItemTerm node);
  visitIE8Term(IE8Term node);
  visitOperatorSlash(OperatorSlash node);
  visitOperatorComma(OperatorComma node);
  visitOperatorPlus(OperatorPlus node);
  visitOperatorMinus(OperatorMinus node);
  visitVarUsage(VarUsage node);

  visitExpressions(Expressions node);
  visitBinaryExpression(BinaryExpression node);
  visitUnaryExpression(UnaryExpression node);

  visitIdentifier(Identifier node);
  visitWildcard(Wildcard node);
  visitThisOperator(ThisOperator node);
  visitNegation(Negation node);

  visitDartStyleExpression(DartStyleExpression node);
  visitFontExpression(FontExpression node);
  visitBoxExpression(BoxExpression node);
  visitMarginExpression(MarginExpression node);
  visitBorderExpression(BorderExpression node);
  visitHeightExpression(HeightExpression node);
  visitPaddingExpression(PaddingExpression node);
  visitWidthExpression(WidthExpression node);
}

/// Base vistor class for the style sheet AST.
class Visitor implements VisitorBase {
  /// Helper function to walk a list of nodes.
  void _visitNodeList(List<TreeNode> list) {
    // Don't use iterable otherwise the list can't grow while using Visitor.
    // It certainly can't have items deleted before the index being iterated
    // but items could be added after the index.
    for (var index = 0; index < list.length; index++) {
      list[index].visit(this);
    }
  }

  visitTree(StyleSheet tree) => visitStyleSheet(tree);

  @override
  visitStyleSheet(StyleSheet ss) {
    _visitNodeList(ss.topLevels);
  }

  @override
  visitNoOp(NoOp node) {}

  @override
  visitTopLevelProduction(TopLevelProduction node) {}

  @override
  visitDirective(Directive node) {}

  @override
  visitCalcTerm(CalcTerm node) {
    visitLiteralTerm(node);
    visitLiteralTerm(node.expr);
  }

  @override
  visitCssComment(CssComment node) {}

  @override
  visitCommentDefinition(CommentDefinition node) {}

  @override
  visitMediaExpression(MediaExpression node) {
    visitExpressions(node.exprs);
  }

  @override
  visitMediaQuery(MediaQuery node) {
    for (var mediaExpr in node.expressions) {
      visitMediaExpression(mediaExpr);
    }
  }

  @override
  visitDocumentDirective(DocumentDirective node) {
    _visitNodeList(node.functions);
    _visitNodeList(node.groupRuleBody);
  }

  @override
  visitSupportsDirective(SupportsDirective node) {
    node.condition.visit(this);
    _visitNodeList(node.groupRuleBody);
  }

  @override
  visitSupportsConditionInParens(SupportsConditionInParens node) {
    node.condition.visit(this);
  }

  @override
  visitSupportsNegation(SupportsNegation node) {
    node.condition.visit(this);
  }

  @override
  visitSupportsConjunction(SupportsConjunction node) {
    _visitNodeList(node.conditions);
  }

  @override
  visitSupportsDisjunction(SupportsDisjunction node) {
    _visitNodeList(node.conditions);
  }

  @override
  visitViewportDirective(ViewportDirective node) {
    node.declarations.visit(this);
  }

  @override
  visitMediaDirective(MediaDirective node) {
    _visitNodeList(node.mediaQueries);
    _visitNodeList(node.rules);
  }

  @override
  visitHostDirective(HostDirective node) {
    _visitNodeList(node.rules);
  }

  @override
  visitPageDirective(PageDirective node) {
    for (var declGroup in node._declsMargin) {
      if (declGroup is MarginGroup) {
        visitMarginGroup(declGroup);
      } else {
        visitDeclarationGroup(declGroup);
      }
    }
  }

  @override
  visitCharsetDirective(CharsetDirective node) {}

  @override
  visitImportDirective(ImportDirective node) {
    for (var mediaQuery in node.mediaQueries) {
      visitMediaQuery(mediaQuery);
    }
  }

  @override
  visitKeyFrameDirective(KeyFrameDirective node) {
    visitIdentifier(node.name);
    _visitNodeList(node._blocks);
  }

  @override
  visitKeyFrameBlock(KeyFrameBlock node) {
    visitExpressions(node._blockSelectors);
    visitDeclarationGroup(node._declarations);
  }

  @override
  visitFontFaceDirective(FontFaceDirective node) {
    visitDeclarationGroup(node._declarations);
  }

  @override
  visitStyletDirective(StyletDirective node) {
    _visitNodeList(node.rules);
  }

  @override
  visitNamespaceDirective(NamespaceDirective node) {}

  @override
  visitVarDefinitionDirective(VarDefinitionDirective node) {
    visitVarDefinition(node.def);
  }

  @override
  visitMixinRulesetDirective(MixinRulesetDirective node) {
    _visitNodeList(node.rulesets);
  }

  @override
  visitMixinDefinition(MixinDefinition node) {}

  @override
  visitMixinDeclarationDirective(MixinDeclarationDirective node) {
    visitDeclarationGroup(node.declarations);
  }

  @override
  visitIncludeDirective(IncludeDirective node) {
    for (var index = 0; index < node.args.length; index++) {
      var param = node.args[index];
      _visitNodeList(param);
    }
  }

  @override
  visitContentDirective(ContentDirective node) {
    // TODO(terry): TBD
  }

  @override
  visitRuleSet(RuleSet node) {
    visitSelectorGroup(node._selectorGroup);
    visitDeclarationGroup(node._declarationGroup);
  }

  @override
  visitDeclarationGroup(DeclarationGroup node) {
    _visitNodeList(node.declarations);
  }

  @override
  visitMarginGroup(MarginGroup node) => visitDeclarationGroup(node);

  @override
  visitDeclaration(Declaration node) {
    visitIdentifier(node._property);
    if (node._expression != null) node._expression.visit(this);
  }

  @override
  visitVarDefinition(VarDefinition node) {
    visitIdentifier(node._property);
    if (node._expression != null) node._expression.visit(this);
  }

  @override
  visitIncludeMixinAtDeclaration(IncludeMixinAtDeclaration node) {
    visitIncludeDirective(node.include);
  }

  @override
  visitExtendDeclaration(ExtendDeclaration node) {
    _visitNodeList(node.selectors);
  }

  @override
  visitSelectorGroup(SelectorGroup node) {
    _visitNodeList(node.selectors);
  }

  @override
  visitSelector(Selector node) {
    _visitNodeList(node.simpleSelectorSequences);
  }

  @override
  visitSimpleSelectorSequence(SimpleSelectorSequence node) {
    node.simpleSelector.visit(this);
  }

  @override
  visitSimpleSelector(SimpleSelector node) => node._name.visit(this);

  @override
  visitNamespaceSelector(NamespaceSelector node) {
    if (node._namespace != null) node._namespace.visit(this);
    if (node.nameAsSimpleSelector != null) {
      node.nameAsSimpleSelector.visit(this);
    }
  }

  @override
  visitElementSelector(ElementSelector node) => visitSimpleSelector(node);

  @override
  visitAttributeSelector(AttributeSelector node) {
    visitSimpleSelector(node);
  }

  @override
  visitIdSelector(IdSelector node) => visitSimpleSelector(node);

  @override
  visitClassSelector(ClassSelector node) => visitSimpleSelector(node);

  @override
  visitPseudoClassSelector(PseudoClassSelector node) =>
      visitSimpleSelector(node);

  @override
  visitPseudoElementSelector(PseudoElementSelector node) =>
      visitSimpleSelector(node);

  @override
  visitPseudoClassFunctionSelector(PseudoClassFunctionSelector node) =>
      visitSimpleSelector(node);

  @override
  visitPseudoElementFunctionSelector(PseudoElementFunctionSelector node) =>
      visitSimpleSelector(node);

  @override
  visitNegationSelector(NegationSelector node) => visitSimpleSelector(node);

  @override
  visitSelectorExpression(SelectorExpression node) {
    _visitNodeList(node.expressions);
  }

  @override
  visitUnicodeRangeTerm(UnicodeRangeTerm node) {}

  @override
  visitLiteralTerm(LiteralTerm node) {}

  @override
  visitHexColorTerm(HexColorTerm node) {}

  @override
  visitNumberTerm(NumberTerm node) {}

  @override
  visitUnitTerm(UnitTerm node) {}

  @override
  visitLengthTerm(LengthTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitPercentageTerm(PercentageTerm node) {
    visitLiteralTerm(node);
  }

  @override
  visitEmTerm(EmTerm node) {
    visitLiteralTerm(node);
  }

  @override
  visitExTerm(ExTerm node) {
    visitLiteralTerm(node);
  }

  @override
  visitAngleTerm(AngleTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitTimeTerm(TimeTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitFreqTerm(FreqTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitFractionTerm(FractionTerm node) {
    visitLiteralTerm(node);
  }

  @override
  visitUriTerm(UriTerm node) {
    visitLiteralTerm(node);
  }

  @override
  visitResolutionTerm(ResolutionTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitChTerm(ChTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitRemTerm(RemTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitViewportTerm(ViewportTerm node) {
    visitUnitTerm(node);
  }

  @override
  visitFunctionTerm(FunctionTerm node) {
    visitLiteralTerm(node);
    visitExpressions(node._params);
  }

  @override
  visitGroupTerm(GroupTerm node) {
    for (var term in node._terms) {
      term.visit(this);
    }
  }

  @override
  visitItemTerm(ItemTerm node) {
    visitNumberTerm(node);
  }

  @override
  visitIE8Term(IE8Term node) {}

  @override
  visitOperatorSlash(OperatorSlash node) {}

  @override
  visitOperatorComma(OperatorComma node) {}

  @override
  visitOperatorPlus(OperatorPlus node) {}

  @override
  visitOperatorMinus(OperatorMinus node) {}

  @override
  visitVarUsage(VarUsage node) {
    _visitNodeList(node.defaultValues);
  }

  @override
  visitExpressions(Expressions node) {
    _visitNodeList(node.expressions);
  }

  @override
  visitBinaryExpression(BinaryExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }

  @override
  visitUnaryExpression(UnaryExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }

  @override
  visitIdentifier(Identifier node) {}

  @override
  visitWildcard(Wildcard node) {}

  @override
  visitThisOperator(ThisOperator node) {}

  @override
  visitNegation(Negation node) {}

  @override
  visitDartStyleExpression(DartStyleExpression node) {}

  @override
  visitFontExpression(FontExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }

  @override
  visitBoxExpression(BoxExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }

  @override
  visitMarginExpression(MarginExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }

  @override
  visitBorderExpression(BorderExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }

  @override
  visitHeightExpression(HeightExpression node) {
    // TODO(terry): TB
    throw UnimplementedError();
  }

  @override
  visitPaddingExpression(PaddingExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }

  @override
  visitWidthExpression(WidthExpression node) {
    // TODO(terry): TBD
    throw UnimplementedError();
  }
}
