//===--- Exprs.swift ------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import ASTBridging
import SwiftDiagnostics
@_spi(ExperimentalLanguageFeatures) @_spi(RawSyntax) import SwiftSyntax

/// Check if an `ExprSyntax` can be generated using ASTGen.
///
/// If all the expression nodes that shares the first token are migrated,
/// returns true. For example, given
///   ```
///   foo.bar({ $0 + 1 }) + 2
///   ```
/// `foo` token is the first token of all `SequenceExpr`, `FunctionCallExpr`,
/// `MemberAccessExpr`, and `DeclReferenceExpr`. All these expression kinds must
/// be migrated to handle it in ASTGen. Because the fallback
/// `generateWithLegacy(_:)` only receives the parser position, it eagerly
/// parses the outer expressions.
func isExprMigrated(_ node: ExprSyntax) -> Bool {
  if node.is(SequenceExprSyntax.self) {
    // 'generate(sequenceExpr:)' is implemented.
    // Since `generateWithLegacy()` only calls `parseExprSequenceElement()`
    // in C++, we don't have to worry about over parsing in the legacy parser.
    return true
  }
  var current: Syntax = Syntax(node)
  if let firstToken = node.firstToken(viewMode: .sourceAccurate) {
    current = firstToken.parent!
  }
  while true {
    switch current.kind {
    case // Known implemented kinds.
        .arrayExpr, .arrowExpr, .assignmentExpr, .binaryOperatorExpr,
        .booleanLiteralExpr, .closureExpr, .discardAssignmentExpr,
        .declReferenceExpr, .functionCallExpr, .ifExpr, .integerLiteralExpr,
        .memberAccessExpr,  .nilLiteralExpr, .postfixOperatorExpr,
        .prefixOperatorExpr, .sequenceExpr, .stringLiteralExpr, .tupleExpr,
        .typeExpr, .unresolvedAsExpr, .unresolvedIsExpr, .unresolvedTernaryExpr:

      // `generate(stringLiteralExpr:)` doesn't support interpolations.
      if let str = current.as(StringLiteralExprSyntax.self) {
        if str.segments.count != 1 {
          return false
        }
        assert(str.segments.first!.is(StringSegmentSyntax.self))
      }

      break
    case // Known unimplemented kinds.
        .asExpr, .awaitExpr,
        .borrowExpr, .canImportExpr, .canImportVersionInfo, .dictionaryExpr,
        .doExpr, .editorPlaceholderExpr,
        .floatLiteralExpr, .forceUnwrapExpr, .inOutExpr, .infixOperatorExpr,
        .isExpr, .keyPathExpr, .macroExpansionExpr, .consumeExpr, .copyExpr,
        .optionalChainingExpr, .packElementExpr, .packExpansionExpr,
        .postfixIfConfigExpr, .regexLiteralExpr, .genericSpecializationExpr,
        .simpleStringLiteralExpr, .subscriptCallExpr, .superExpr, .switchExpr,
        .ternaryExpr, .tryExpr, .patternExpr:
      return false
    case // Unknown expr kinds.
      _ where current.is(ExprSyntax.self):
      return false
    default:
      break
    }
    if current.id == node.id {
      return true
    }
    // This is walking up the parents from the first token of `node`. `.parent`
    // must exist if `current` is not `node`
    current = current.parent!
  }
}

extension ASTGenVisitor {
  func generate(expr node: ExprSyntax) -> BridgedExpr {
    guard isExprMigrated(node) else {
      return generateWithLegacy(node)
    }
    switch node.as(ExprSyntaxEnum.self) {
    case .arrayExpr(let node):
      return self.generate(arrayExpr: node).asExpr
    case .arrowExpr:
      preconditionFailure("should be handled in generate(sequenceExpr:)")
    case .asExpr:
      break
    case .assignmentExpr:
      preconditionFailure("should be handled in generate(sequenceExpr:)")
    case .awaitExpr:
      break
    case .binaryOperatorExpr:
      preconditionFailure("should be handled in generate(sequenceExpr:)")
    case .booleanLiteralExpr(let node):
      return self.generate(booleanLiteralExpr: node).asExpr
    case .borrowExpr:
      break
    case .canImportExpr:
      break
    case .canImportVersionInfo:
      break
    case .closureExpr(let node):
      return self.generate(closureExpr: node).asExpr
    case .consumeExpr:
      break
    case .copyExpr:
      break
    case .declReferenceExpr(let node):
      return self.generate(declReferenceExpr: node).asExpr
    case .dictionaryExpr:
      break
    case .discardAssignmentExpr(let node):
      return self.generate(discardAssignmentExpr: node).asExpr
    case .doExpr:
      break
    case .editorPlaceholderExpr:
      break
    case .floatLiteralExpr:
      break
    case .forceUnwrapExpr:
      break
    case .functionCallExpr(let node):
      return self.generate(functionCallExpr: node).asExpr
    case .genericSpecializationExpr:
      break
    case .ifExpr(let node):
      return self.generate(ifExpr: node).asExpr
    case .inOutExpr:
      break
    case .infixOperatorExpr:
      break
    case .integerLiteralExpr(let node):
      return self.generate(integerLiteralExpr: node).asExpr
    case .isExpr:
      break
    case .keyPathExpr:
      break
    case .macroExpansionExpr:
      break
    case .memberAccessExpr(let node):
      return self.generate(memberAccessExpr: node)
    case .missingExpr:
      break
    case .nilLiteralExpr(let node):
      return self.generate(nilLiteralExpr: node).asExpr
    case .optionalChainingExpr:
      // Need special care to wrap the entire postfix chain with OptionalEvaluationExpr.
      break
    case .packElementExpr:
      break
    case .packExpansionExpr:
      break
    case .patternExpr:
      break
    case .postfixIfConfigExpr:
      break
    case .postfixOperatorExpr(let node):
      return self.generate(postfixOperatorExpr: node).asExpr
    case .prefixOperatorExpr(let node):
      return self.generate(prefixOperatorExpr: node).asExpr
    case .regexLiteralExpr:
      break
    case .sequenceExpr(let node):
      return self.generate(sequenceExpr: node)
    case .simpleStringLiteralExpr:
      break
    case .stringLiteralExpr(let node):
      return self.generate(stringLiteralExpr: node).asExpr
    case .subscriptCallExpr:
      break
    case .superExpr:
      break
    case .switchExpr:
      break
    case .ternaryExpr:
      break
    case .tryExpr:
      break
    case .tupleExpr(let node):
      return self.generate(tupleExpr: node).asExpr
    case .typeExpr(let node):
      return self.generate(typeExpr: node).asExpr
    case .unresolvedAsExpr:
      preconditionFailure("should be handled in generate(sequenceExpr:)")
    case .unresolvedIsExpr:
      preconditionFailure("should be handled in generate(sequenceExpr:)")
    case .unresolvedTernaryExpr:
      preconditionFailure("should be handled in generate(sequenceExpr:)")
    }
    preconditionFailure("isExprMigrated() mismatch")
  }

  func generate(arrowExpr node: ArrowExprSyntax) -> BridgedArrowExpr {
    let asyncLoc: BridgedSourceLoc
    let throwsLoc: BridgedSourceLoc
    let thrownTypeExpr: BridgedNullableExpr

    if let effectSpecifiers = node.effectSpecifiers {
      asyncLoc = self.generateSourceLoc(effectSpecifiers.asyncSpecifier)
      throwsLoc = self.generateSourceLoc(effectSpecifiers.throwsClause?.throwsSpecifier)
      if let thrownTypeNode = effectSpecifiers.thrownError {
        let typeExpr = BridgedTypeExpr.createParsed(
          self.ctx,
          type: self.generate(type: thrownTypeNode)
        )
        thrownTypeExpr = BridgedNullableExpr(raw: typeExpr.raw)
      } else {
        thrownTypeExpr = nil
      }
    } else {
      asyncLoc = nil
      throwsLoc = nil
      thrownTypeExpr = nil
    }

    return .createParsed(
      self.ctx,
      asyncLoc: asyncLoc,
      throwsLoc: throwsLoc,
      thrownType: thrownTypeExpr,
      arrowLoc: self.generateSourceLoc(node.arrow)
    )
  }

  func generate(assignmentExpr node: AssignmentExprSyntax) -> BridgedAssignExpr {
    return .createParsed(self.ctx, equalsLoc: self.generateSourceLoc(node.equal))
  }

  func generate(binaryOperatorExpr node: BinaryOperatorExprSyntax) -> BridgedUnresolvedDeclRefExpr {
    return createOperatorRefExpr(token: node.operator, kind: .binaryOperator)
  }

  func generate(closureExpr node: ClosureExprSyntax) -> BridgedClosureExpr {
    let body = BridgedBraceStmt.createParsed(
      self.ctx,
      lBraceLoc: self.generateSourceLoc(node.leftBrace),
      elements: self.generate(codeBlockItemList: node.statements),
      rBraceLoc: self.generateSourceLoc(node.rightBrace)
    )

    // FIXME: Translate the signature, capture list, 'in' location, etc.
    return .createParsed(self.ctx, declContext: self.declContext, body: body)
  }

  func generate(functionCallExpr node: FunctionCallExprSyntax) -> BridgedCallExpr {
    if !node.arguments.isEmpty || node.trailingClosure == nil {
      if node.leftParen == nil {
        self.diagnose(
          Diagnostic(node: node, message: MissingChildTokenError(parent: node, kindOfTokenMissing: .leftParen))
        )
      }
      if node.rightParen == nil {
        self.diagnose(
          Diagnostic(node: node, message: MissingChildTokenError(parent: node, kindOfTokenMissing: .rightParen))
        )
      }
    }

    var node = node

    // Transform the trailing closure into an argument.
    if let trailingClosure = node.trailingClosure {
      let tupleElement = LabeledExprSyntax(
        label: nil,
        colon: nil,
        expression: ExprSyntax(trailingClosure),
        trailingComma: nil
      )

      node.arguments.append(tupleElement)
      node.trailingClosure = nil
    }

    let argumentTuple = self.generate(
      labeledExprList: node.arguments,
      leftParen: node.leftParen,
      rightParen: node.rightParen
    )
    let callee = generate(expr: node.calledExpression)

    return .createParsed(self.ctx, fn: callee, args: argumentTuple)
  }

  private func createDeclNameRef(declReferenceExpr node: DeclReferenceExprSyntax) -> (name: BridgedDeclNameRef, loc: BridgedDeclNameLoc) {
    let baseName: BridgedDeclBaseName
    switch node.baseName.keywordKind {
    case .`init`:
      baseName = .createConstructor()
    case .deinit:
      baseName = .createDestructor()
    case .subscript:
      baseName = .createSubscript()
    default:
      baseName = .createIdentifier(self.generateIdentifier(node.baseName))
    }
    let baseNameLoc = self.generateSourceLoc(node.baseName)

    if let argumentClause = node.argumentNames {
      let labels = argumentClause.arguments.lazy.map {
        self.generateIdentifier($0.name)
      }
      let labelLocs = argumentClause.arguments.lazy.map {
        self.generateSourceLoc($0.name)
      }
      return (
        name: .createParsed(
          self.ctx,
          baseName: baseName,
          argumentLabels: labels.bridgedArray(in: self)
        ),
        loc: .createParsed(
          self.ctx,
          baseNameLoc: baseNameLoc,
          lParenLoc: self.generateSourceLoc(argumentClause.leftParen),
          argumentLabelLocs: labelLocs.bridgedArray(in: self),
          rParenLoc: self.generateSourceLoc(argumentClause.rightParen)
        )
      )
    } else {
      return (
        name: .createParsed(baseName),
        loc: .createParsed(baseNameLoc)
      )
    }
  }

  func generate(declReferenceExpr node: DeclReferenceExprSyntax) -> BridgedUnresolvedDeclRefExpr {
    let nameAndLoc = createDeclNameRef(declReferenceExpr: node)
    return .createParsed(
      self.ctx,
      name: nameAndLoc.name,
      kind: .ordinary,
      loc: nameAndLoc.loc
    )
  }

  func generate(discardAssignmentExpr node: DiscardAssignmentExprSyntax) -> BridgedDiscardAssignmentExpr {
    return .createParsed(self.ctx, loc: self.generateSourceLoc(node.wildcard))
  }

  func generate(memberAccessExpr node: MemberAccessExprSyntax) -> BridgedExpr {
    let dotLoc = self.generateSourceLoc(node.period)
    let nameAndLoc = createDeclNameRef(declReferenceExpr: node.declName)

    if let base = node.base {
      if node.declName.baseName.keywordKind == .`self` {
        // TODO: Diagnose if there's arguments
        assert(node.declName.argumentNames == nil)

        return BridgedDotSelfExpr.createParsed(
          self.ctx,
          subExpr: self.generate(expr: base),
          dotLoc: dotLoc,
          selfLoc: self.generateSourceLoc(node.declName)
        ).asExpr
      } else {
        return BridgedUnresolvedDotExpr.createParsed(
          self.ctx,
          base: self.generate(expr: base),
          dotLoc: dotLoc,
          name: nameAndLoc.name,
          nameLoc: nameAndLoc.loc
        ).asExpr
      }
    } else {
      return BridgedUnresolvedMemberExpr.createParsed(
        self.ctx,
        dotLoc: dotLoc,
        name: nameAndLoc.name,
        nameLoc: nameAndLoc.loc
      ).asExpr
    }
  }

  func generate(ifExpr node: IfExprSyntax) -> BridgedSingleValueStmtExpr {
    let stmt = makeIfStmt(node).asStmt

    // Wrap in a SingleValueStmtExpr to embed as an expression.
    return .createWithWrappedBranches(
      ctx,
      stmt: stmt,
      declContext: declContext,
      mustBeExpr: true
    )
  }

  func generate(postfixOperatorExpr node: PostfixOperatorExprSyntax) -> BridgedPostfixUnaryExpr {
    return .createParsed(
      self.ctx,
      operator: self.createOperatorRefExpr(
        token: node.operator,
        kind: .postfixOperator
      ).asExpr,
      operand: self.generate(expr: node.expression)
    )
  }

  func generate(prefixOperatorExpr node: PrefixOperatorExprSyntax) -> BridgedPrefixUnaryExpr {
    return .createParsed(
      self.ctx,
      operator: self.createOperatorRefExpr(
        token: node.operator,
        kind: .prefixOperator
      ).asExpr,
      operand: self.generate(expr: node.expression)
    )
  }

  func generate(sequenceExpr node: SequenceExprSyntax) -> BridgedExpr {
    assert(
      !node.elements.count.isMultiple(of: 2),
      "SequenceExpr must have odd number of elements"
    )

    guard node.elements.count > 1 else {
      // Should be unreachable if the `node` is a parsed by `SwiftParser`.
      return self.generate(expr: node.elements.first!)
    }

    // NOTE: we can't just generate(expr:) for each elements because
    // SwiftSyntax.SequenceExprSyntax and swift::SequenceExpr has mismatch in the
    // element representations. e.g. 'as' and 'is'.

    // FIXME: Avoid Swift.Array.
    var elements: [BridgedExpr] = []
    elements.reserveCapacity(node.elements.count)

    var iter = node.elements.makeIterator()
    while let node = iter.next() {
      switch node.as(ExprSyntaxEnum.self) {
      case .arrowExpr(let node):
        elements.append(self.generate(arrowExpr: node).asExpr)
      case .assignmentExpr(let node):
        elements.append(self.generate(assignmentExpr: node).asExpr)
      case .binaryOperatorExpr(let node):
        elements.append(self.generate(binaryOperatorExpr: node).asExpr)
      case .unresolvedAsExpr(let node):
        let oper = self.generate(
          unresolvedAsExpr: node,
          typeExpr: iter.next()!.cast(TypeExprSyntax.self)
        )
        elements.append(oper)
        elements.append(oper)
      case .unresolvedIsExpr(let node):
        let oper = self.generate(
          unresolvedIsExpr: node,
          typeExpr: iter.next()!.cast(TypeExprSyntax.self)
        )
        elements.append(oper.asExpr)
        elements.append(oper.asExpr)
      case .unresolvedTernaryExpr(let node):
        elements.append(self.generate(unresolvedTernaryExpr: node).asExpr)
      default:
        // Operand.
        elements.append(self.generate(expr: node))
      }
    }

    return BridgedSequenceExpr.createParsed(
      self.ctx,
      exprs: elements.lazy.bridgedArray(in: self)
    ).asExpr
  }

  func generate(tupleExpr node: TupleExprSyntax) -> BridgedTupleExpr {
    return self.generate(labeledExprList: node.elements, leftParen: node.leftParen, rightParen: node.rightParen)
  }

  func generate(typeExpr node: TypeExprSyntax) -> BridgedTypeExpr {
    return .createParsed(
      self.ctx,
      type: self.generate(type: node.type)
    )
  }

  func generate(unresolvedAsExpr node: UnresolvedAsExprSyntax, typeExpr typeNode: TypeExprSyntax) -> BridgedExpr {
    let type = self.generate(type: typeNode.type)
    let asLoc = self.generateSourceLoc(node.asKeyword)

    switch node.questionOrExclamationMark {
    case nil:
      return BridgedCoerceExpr.createParsed(
        self.ctx,
        asLoc: asLoc,
        type: type
      ).asExpr
    case let question? where question.rawTokenKind == .postfixQuestionMark:
      return BridgedConditionalCheckedCastExpr.createParsed(
        self.ctx,
        asLoc: asLoc,
        questionLoc: self.generateSourceLoc(question),
        type: type
      ).asExpr
    case let exclaim? where exclaim.rawTokenKind == .exclamationMark:
      return BridgedForcedCheckedCastExpr.createParsed(
        self.ctx,
        asLoc: asLoc,
        exclaimLoc: self.generateSourceLoc(exclaim),
        type: type
      ).asExpr
    case _?:
      preconditionFailure("UnresolvedAsExprSyntax must have '?' or '!'")
    }
  }

  func generate(unresolvedIsExpr node: UnresolvedIsExprSyntax, typeExpr typeNode: TypeExprSyntax) -> BridgedIsExpr {
    return .createParsed(
      self.ctx,
      isLoc: self.generateSourceLoc(node.isKeyword),
      type: self.generate(type: typeNode.type)
    )
  }

  func generate(unresolvedTernaryExpr node: UnresolvedTernaryExprSyntax) -> BridgedTernaryExpr {
    return .createParsed(
      self.ctx,
      questionLoc: self.generateSourceLoc(node.questionMark),
      thenExpr: self.generate(expr: node.thenExpression),
      colonLoc: self.generateSourceLoc(node.colon)
    )
  }

  // NOTE: When implementing new `generate(expr:)`, please update `isExprMigrated(_:)`.
}

extension ASTGenVisitor {
  fileprivate func createOperatorRefExpr(token node: TokenSyntax, kind: BridgedDeclRefKind) -> BridgedUnresolvedDeclRefExpr {
    let (name, nameLoc) = self.generateIdentifierAndSourceLoc(node)

    return .createParsed(
      self.ctx,
      name: .createParsed(.createIdentifier(name)),
      kind: kind,
      loc: .createParsed(nameLoc)
    );
  }


  /// Generate a tuple expression from a ``LabeledExprListSyntax`` and parentheses.
  func generate(labeledExprList node: LabeledExprListSyntax, leftParen: TokenSyntax?, rightParen: TokenSyntax?) -> BridgedTupleExpr {
    let expressions = node.lazy.map {
      self.generate(expr: $0.expression)
    }
    let labels = node.lazy.map {
      self.generateIdentifier($0.label)
    }
    let labelLocations = node.lazy.map {
      if let label = $0.label {
        return self.generateSourceLoc(label)
      }

      return self.generateSourceLoc($0)
    }

    return BridgedTupleExpr.createParsed(
      self.ctx,
      leftParenLoc: self.generateSourceLoc(leftParen),
      exprs: expressions.bridgedArray(in: self),
      labels: labels.bridgedArray(in: self),
      labelLocs: labelLocations.bridgedArray(in: self),
      rightParenLoc: self.generateSourceLoc(rightParen)
    )
  }
}
