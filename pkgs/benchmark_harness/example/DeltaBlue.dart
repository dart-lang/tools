// Copyright 2011 Google Inc. All Rights Reserved.
// Copyright 1996 John Maloney and Mario Wolczko
//
// This file is part of GNU Smalltalk.
//
// GNU Smalltalk is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 2, or (at your option) any later version.
//
// GNU Smalltalk is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// GNU Smalltalk; see the file COPYING.  If not, write to the Free Software
// Foundation, 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
//
// Translated first from Smalltalk to JavaScript, and finally to
// Dart by Google 2008-2010.

/**
 * A Dart implementation of the DeltaBlue constraint-solving
 * algorithm, as described in:
 *
 * "The DeltaBlue Algorithm: An Incremental Constraint Hierarchy Solver"
 *   Bjorn N. Freeman-Benson and John Maloney
 *   January 1990 Communications of the ACM,
 *   also available as University of Washington TR 89-08-06.
 *
 * Beware: this benchmark is written in a grotesque style where
 * the constraint model is built by side-effects from constructors.
 * I've kept it this way to avoid deviating too much from the original
 * implementation.
 */

import 'package:benchmark_harness/benchmark_harness.dart';

 main() {
   DeltaBlue.main();
 }

/* --- *
 * S t r e n g t h
 * --- */

/**
 * Strengths are used to measure the relative importance of constraints.
 * New strengths may be inserted in the strength hierarchy without
 * disrupting current constraints.  Strengths cannot be created outside
 * this class, so == can be used for value comparison.
 */

class Strength {

  final int value;
  final String name;

  const Strength(this.value, this.name);

  Strength nextWeaker() {
    if (this.value == 0) return WEAKEST;
    if (this.value == 1) return WEAK_DEFAULT;
    if (this.value == 2) return NORMAL;
    if (this.value == 3) return STRONG_DEFAULT;
    if (this.value == 4) return PREFERRED;
    if (this.value == 5) return REQUIRED;
  }

  static bool stronger(Strength s1, Strength s2) {
    return s1.value < s2.value;
  }

  static bool weaker(Strength s1, Strength s2) {
    return s1.value > s2.value;
  }

  static Strength weakest(Strength s1, Strength s2) {
    return weaker(s1, s2) ? s1 : s2;
  }

  static Strength strongest(Strength s1, Strength s2) {
    return stronger(s1, s2) ? s1 : s2;
  }

  // Compile time computed constants.
  static Strength REQUIRED;
  static Strength STRONG_REFERRED;
  static Strength PREFERRED;
  static Strength STRONG_DEFAULT;
  static Strength NORMAL;
  static Strength WEAK_DEFAULT;
  static Strength WEAKEST;

  static List<Strength> STRENGTHS;

  static void init() {
    REQUIRED        = const Strength(0, "required");
    STRONG_REFERRED = const Strength(1, "strongPreferred");
    PREFERRED       = const Strength(2, "preferred");
    STRONG_DEFAULT  = const Strength(3, "strongDefault");
    NORMAL          = const Strength(4, "normal");
    WEAK_DEFAULT    = const Strength(5, "weakDefault");
    WEAKEST         = const Strength(6, "weakest");
    STRENGTHS       = <Strength>[REQUIRED, STRONG_REFERRED, PREFERRED,
                                 STRONG_DEFAULT, NORMAL, WEAK_DEFAULT,
                                 WEAKEST];
  }
}

class Constraint {

  final Strength strength;

  const Constraint(this.strength);

  bool isSatisfied() {}
  void markUnsatisfied() {}
  void addToGraph() {}
  void removeFromGraph() {}
  void chooseMethod(int mark) {}
  void markInputs(int mark) {}
  bool inputsKnown(int mark) {}
  Variable output() {}
  void execute() {}
  void recalculate() {}

  /**
   * Activate this constraint and attempt to satisfy it.
   */
  void addConstraint() {
    addToGraph();
    DeltaBlue.planner.incrementalAdd(this);
  }

  /**
   * Attempt to find a way to enforce this constraint. If successful,
   * record the solution, perhaps modifying the current dataflow
   * graph. Answer the constraint that this constraint overrides, if
   * there is one, or nil, if there isn't.
   * Assume: I am not already satisfied.
   */
  Constraint satisfy(mark) {
    chooseMethod(mark);
    if (!isSatisfied()) {
      if (strength == Strength.REQUIRED)
        DeltaBlue.log("Could not satisfy a required constraint!");
      return null;
    }
    markInputs(mark);
    Variable out = output();
    Constraint overridden = out.determinedBy;
    if (overridden != null) overridden.markUnsatisfied();
    out.determinedBy = this;
    if (!DeltaBlue.planner.addPropagate(this, mark)) {
      DeltaBlue.log("Cycle encountered");
    }
    out.mark = mark;
    return overridden;
  }

  void destroyConstraint() {
    if (isSatisfied()) DeltaBlue.planner.incrementalRemove(this);
    removeFromGraph();
  }

  /**
   * Normal constraints are not input constraints.  An input constraint
   * is one that depends on external state, such as the mouse, the
   * keybord, a clock, or some arbitraty piece of imperative code.
   */
  bool isInput() {
    return false;
  }
}

/* --- *
 * U n a r y   C o n s t r a i n t
 * --- */

class UnaryConstraint extends Constraint {

  /**
   * Abstract superclass for constraints having a single possible output
   * variable.
   */
  UnaryConstraint(Variable v, Strength strength)
      : super(strength), myOutput = v, satisfied = false {
    this.addConstraint();
  }

  /**
   * Adds this constraint to the constraint graph
   */
  void addToGraph() {
    myOutput.addConstraint(this);
    satisfied = false;
  }

  /**
   * Decides if this constraint can be satisfied and records that
   * decision.
   */
  void chooseMethod(int mark) {
    satisfied = (myOutput.mark != mark)
      && Strength.stronger(this.strength, myOutput.walkStrength);
  }

  /**
   * Returns true if this constraint is satisfied in the current solution.
   */
  bool isSatisfied() {
    return satisfied;
  }

  void markInputs(int mark) {
    // has no inputs.
  }

  /**
   * Returns the current output variable.
   */
  Variable output() {
    return myOutput;
  }

  /**
   * Calculate the walkabout strength, the stay flag, and, if it is
   * 'stay', the value for the current output of this constraint. Assume
   * this constraint is satisfied.
   */
  void recalculate() {
    myOutput.walkStrength = this.strength;
    myOutput.stay = !this.isInput();
    if (myOutput.stay) this.execute(); // Stay optimization.
  }

  /**
   * Records that this constraint is unsatisfied
   */
  void markUnsatisfied() {
    satisfied = false;
  }

  bool inputsKnown(int mark) {
    return true;
  }

  void removeFromGraph() {
    if (myOutput != null) myOutput.removeConstraint(this);
    satisfied = false;
  }

  final Variable myOutput;
  bool satisfied;
}



/* --- *
 * S t a y   C o n s t r a i n t
 * --- */

/**
 * Variables that should, with some level of preference, stay the same.
 * Planners may exploit the fact that instances, if satisfied, will not
 * change their output during plan execution.  This is called "stay
 * optimization".
 */

class StayConstraint extends UnaryConstraint {

  StayConstraint(Variable v, Strength str) : super(v, str) {
  }

  void execute() {
    // Stay constraints do nothing.
  }
}


/* --- *
 * E d i t   C o n s t r a i n t
 * --- */

class EditConstraint extends UnaryConstraint {

  /**
   * A unary input constraint used to mark a variable that the client
   * wishes to change.
   */
  EditConstraint(Variable v, Strength str) : super(v, str) { }

  /**
   * Edits indicate that a variable is to be changed by imperative code.
   */
  bool isInput() {
    return true;
  }

  void execute() {
    // Edit constraints do nothing.
  }
}


class Direction {
  static const int NONE = 1;
  static const int FORWARD = 2;
  static const int BACKWARD = 0;
}


/* --- *
 * B i n a r y   C o n s t r a i n t
 * --- */

class BinaryConstraint extends Constraint {
  Variable v1;
  Variable v2;
  int direction;

  /**
   * Abstract superclass for constraints having two possible output
   * variables.
   */
  BinaryConstraint(Variable var1, Variable var2, Strength strength)
      : super(strength), v1 = var1, v2 = var2, direction = Direction.NONE {
    this.addConstraint();
  }

  /**
   * Decides if this constraint can be satisfied and which way it
   * should flow based on the relative strength of the variables related,
   * and record that decision.
   */
  void chooseMethod(int mark) {
    if (v1.mark == mark) {
      direction = (v2.mark != mark &&
                   Strength.stronger(this.strength, v2.walkStrength))
        ? Direction.FORWARD
        : Direction.NONE;
    }
    if (v2.mark == mark) {
      direction = (v1.mark != mark &&
                   Strength.stronger(this.strength, v1.walkStrength))
        ? Direction.BACKWARD
        : Direction.NONE;
    }
    if (Strength.weaker(v1.walkStrength, v2.walkStrength)) {
      direction = Strength.stronger(this.strength, v1.walkStrength)
        ? Direction.BACKWARD
        : Direction.NONE;
    } else {
      direction = Strength.stronger(this.strength, v2.walkStrength)
        ? Direction.FORWARD
        : Direction.BACKWARD;
    }
  }

  /**
   * Add this constraint to the constraint graph
   */
  void addToGraph() {
    v1.addConstraint(this);
    v2.addConstraint(this);
    direction = Direction.NONE;
  }

  /**
   * Answer true if this constraint is satisfied in the current solution.
   */
  bool isSatisfied() {
    return direction != Direction.NONE;
  }

  /**
   * Mark the input variable with the given mark.
   */
  void markInputs(int mark) {
    input().mark = mark;
  }

  /**
   * Returns the current input variable
   */
  Variable input() {
    return (direction == Direction.FORWARD) ? v1 : v2;
  }

  /**
   * Returns the current output variable
   */
  Variable output() {
    return (direction == Direction.FORWARD) ? v2 : v1;
  }

  /**
   * Calculate the walkabout strength, the stay flag, and, if it is
   * 'stay', the value for the current output of this
   * constraint. Assume this constraint is satisfied.
   */
  void recalculate() {
    Variable ihn = input(), out = output();
    out.walkStrength = Strength.weakest(this.strength, ihn.walkStrength);
    out.stay = ihn.stay;
    if (out.stay) this.execute();
  }

  /**
   * Record the fact that this constraint is unsatisfied.
   */
  void markUnsatisfied() {
    direction = Direction.NONE;
  }

  bool inputsKnown(int mark) {
    Variable i = input();
    return i.mark == mark || i.stay || i.determinedBy == null;
  }

  void removeFromGraph() {
    if (v1 != null) v1.removeConstraint(this);
    if (v2 != null) v2.removeConstraint(this);
    direction = Direction.NONE;
  }
}


/* --- *
 * S c a l e   C o n s t r a i n t
 * --- */

/**
 * Relates two variables by the linear scaling relationship: "v2 =
 * (v1 * scale) + offset". Either v1 or v2 may be changed to maintain
 * this relationship but the scale factor and offset are considered
 * read-only.
 */

class ScaleConstraint extends BinaryConstraint {

  ScaleConstraint(Variable src, Variable scale, Variable offset,
                  Variable dest, Strength strength)
      : super(src, dest, strength), this.scale = scale, this.offset = offset {}

  /**
   * Adds this constraint to the constraint graph.
   */
  void addToGraph() {
    super.addToGraph();
    scale.addConstraint(this);
    offset.addConstraint(this);
  }

  void removeFromGraph() {
    super.removeFromGraph();
    if (scale != null) scale.removeConstraint(this);
    if (offset != null) offset.removeConstraint(this);
  }

  void markInputs(int mark) {
    super.markInputs(mark);
    scale.mark = offset.mark = mark;
  }

  /**
   * Enforce this constraint. Assume that it is satisfied.
   */
  void execute() {
    if (this.direction == Direction.FORWARD) {
      this.v2.value = this.v1.value * scale.value + offset.value;
    } else {
      this.v1.value = (this.v2.value - offset.value) ~/ scale.value;
    }
  }

  /**
   * Calculate the walkabout strength, the stay flag, and, if it is
   * 'stay', the value for the current output of this constraint. Assume
   * this constraint is satisfied.
   */
  void recalculate() {
    Variable ihn = this.input(), out = this.output();
    out.walkStrength = Strength.weakest(this.strength, ihn.walkStrength);
    out.stay = ihn.stay && scale.stay && offset.stay;
    if (out.stay) this.execute();
  }

  final Variable scale;
  final Variable offset;
}

/* --- *
 * E q u a l i t  y   C o n s t r a i n t
 * --- */

/**
 * Constrains two variables to have the same value.
 */

class EqualityConstraint extends BinaryConstraint {

  EqualityConstraint(Variable var1, Variable var2, Strength strength)
      : super(var1, var2, strength) { }

  /**
   * Enforce this constraint. Assume that it is satisfied.
   */
  void execute() {
    this.output().value = this.input().value;
  }
}


/* --- *
 * V a r i a b l e
 * --- */

/**
 * A constrained variable. In addition to its value, it maintain the
 * structure of the constraint graph, the current dataflow graph, and
 * various parameters of interest to the DeltaBlue incremental
 * constraint solver.
 **/

class Variable {
  int value;
  List<Constraint> constraints;
  Constraint determinedBy;
  int mark;
  Strength walkStrength;
  bool stay;
  final String name;

  Variable(String name, int value) : this.name = name, this.value = value {
    constraints = new List<Constraint>();
    mark = 0;
    walkStrength = Strength.WEAKEST;
    stay = true;
  }

  /**
   * Add the given constraint to the set of all constraints that refer
   * this variable.
   */
  void addConstraint(Constraint c) {
    constraints.add(c);
  }

  /*
   * Removes all traces of c from this variable.
   */
  void removeConstraint(Constraint c) {
    constraints = constraints.filter(bool _(e) { return c != e; });
    if (determinedBy == c) determinedBy = null;
  }
}


/* --- *
 * P l a n n e r
 * --- */

class Planner {

  Planner() {
    currentMark = 0;
  }

  /**
   * Attempt to satisfy the given constraint and, if successful,
   * incrementally update the dataflow graph.  Details: If satifying
   * the constraint is successful, it may override a weaker constraint
   * on its output. The algorithm attempts to resatisfy that
   * constraint using some other method. This process is repeated
   * until either a) it reaches a variable that was not previously
   * determined by any constraint or b) it reaches a constraint that
   * is too weak to be satisfied using any of its methods. The
   * variables of constraints that have been processed are marked with
   * a unique mark value so that we know where we've been. This allows
   * the algorithm to avoid getting into an infinite loop even if the
   * constraint graph has an inadvertent cycle.
   */
  void incrementalAdd(Constraint c) {
    int  mark = newMark();
    for(Constraint overridden = c.satisfy(mark);
        overridden != null;
        overridden = overridden.satisfy(mark)) {}
  }

  /**
   * Entry point for retracting a constraint. Remove the given
   * constraint and incrementally update the dataflow graph.
   * Details: Retracting the given constraint may allow some currently
   * unsatisfiable downstream constraint to be satisfied. We therefore collect
   * a list of unsatisfied downstream constraints and attempt to
   * satisfy each one in turn. This list is traversed by constraint
   * strength, strongest first, as a heuristic for avoiding
   * unnecessarily adding and then overriding weak constraints.
   * Assume: c is satisfied.
   */
  void incrementalRemove(Constraint c) {
    Variable out = c.output();
    c.markUnsatisfied();
    c.removeFromGraph();
    List unsatisfied = removePropagateFrom(out);
    Strength strength = Strength.REQUIRED;
    do {
      for (int i = 0; i < unsatisfied.length; i++) {
        Constraint u = unsatisfied[i];
        if (u.strength == strength)
          incrementalAdd(u);
      }
      strength = strength.nextWeaker();
    } while (strength != Strength.WEAKEST);
  }

  /**
   * Select a previously unused mark value.
   */
  int newMark() {
    return ++currentMark;
  }

  /**
   * Extract a plan for resatisfaction starting from the given source
   * constraints, usually a set of input constraints. This method
   * assumes that stay optimization is desired; the plan will contain
   * only constraints whose output variables are not stay. Constraints
   * that do no computation, such as stay and edit constraints, are
   * not included in the plan.
   * Details: The outputs of a constraint are marked when it is added
   * to the plan under construction. A constraint may be appended to
   * the plan when all its input variables are known. A variable is
   * known if either a) the variable is marked (indicating that has
   * been computed by a constraint appearing earlier in the plan), b)
   * the variable is 'stay' (i.e. it is a constant at plan execution
   * time), or c) the variable is not determined by any
   * constraint. The last provision is for past states of history
   * variables, which are not stay but which are also not computed by
   * any constraint.
   * Assume: sources are all satisfied.
   */
  Plan makePlan(List<Constraint> sources) {
    int mark = newMark();
    Plan plan = new Plan();
    List<Constraint> todo = sources;
    while (todo.length > 0) {
      Constraint c = todo.removeLast();
      if (c.output().mark != mark && c.inputsKnown(mark)) {
        plan.addConstraint(c);
        c.output().mark = mark;
        addConstraintsConsumingTo(c.output(), todo);
      }
    }
    return plan;
  }

  /**
   * Extract a plan for resatisfying starting from the output of the
   * given constraints, usually a set of input constraints.
   */
  Plan extractPlanFromConstraints(List<Constraint> constraints) {
    List<Constraint> sources = new List<Constraint>();
    for (int i = 0; i < constraints.length; i++) {
      Constraint c = constraints[i];
      if (c.isInput() && c.isSatisfied())
        // not in plan already and eligible for inclusion.
        sources.add(c);
    }
    return makePlan(sources);
  }

  /**
   * Recompute the walkabout strengths and stay flags of all variables
   * downstream of the given constraint and recompute the actual
   * values of all variables whose stay flag is true. If a cycle is
   * detected, remove the given constraint and answer
   * false. Otherwise, answer true.
   * Details: Cycles are detected when a marked variable is
   * encountered downstream of the given constraint. The sender is
   * assumed to have marked the inputs of the given constraint with
   * the given mark. Thus, encountering a marked node downstream of
   * the output constraint means that there is a path from the
   * constraint's output to one of its inputs.
   */
  bool addPropagate(Constraint c, int mark) {
    List<Constraint> todo = new List<Constraint>();
    todo.add(c);
    while (todo.length > 0) {
      Constraint d = todo.removeLast();
      if (d.output().mark == mark) {
        incrementalRemove(c);
        return false;
      }
      d.recalculate();
      addConstraintsConsumingTo(d.output(), todo);
    }
    return true;
  }

  /**
   * Update the walkabout strengths and stay flags of all variables
   * downstream of the given constraint. Answer a collection of
   * unsatisfied constraints sorted in order of decreasing strength.
   */
  List removePropagateFrom(Variable out) {
    out.determinedBy = null;
    out.walkStrength = Strength.WEAKEST;
    out.stay = true;
    List<Constraint> unsatisfied = new List<Constraint>();
    List<Variable> todo = new List<Variable>();
    todo.add(out);
    while (todo.length > 0) {
      Variable v = todo.removeLast();
      for (int i = 0; i < v.constraints.length; i++) {
        Constraint c = v.constraints[i];
        if (!c.isSatisfied())
          unsatisfied.add(c);
      }
      Constraint determining = v.determinedBy;
      for (int i = 0; i < v.constraints.length; i++) {
        Constraint next = v.constraints[i];
        if (next != determining && next.isSatisfied()) {
          next.recalculate();
          todo.add(next.output());
        }
      }
    }
    return unsatisfied;
  }

  void addConstraintsConsumingTo(Variable v, List<Constraint> coll) {
    Constraint determining = v.determinedBy;
    for (int i = 0; i < v.constraints.length; i++) {
      Constraint c = v.constraints[i];
      if (c != determining && c.isSatisfied()) coll.add(c);
    }
  }

  int currentMark;
}


/* --- *
 * P l a n
 * --- */

/**
 * A Plan is an ordered list of constraints to be executed in sequence
 * to resatisfy all currently satisfiable constraints in the face of
 * one or more changing inputs.
 */

class Plan {

  Plan() : list = new List<Constraint>() { }

  void addConstraint(Constraint c) {
    list.add(c);
  }

  int size() {
    return list.length;
  }

  void execute() {
    for (int i = 0; i < list.length; i++) {
      list[i].execute();
    }
  }

  List<Constraint> list;
}


/**
 * This is the standard DeltaBlue benchmark. A long chain of equality
 * constraints is constructed with a stay constraint on one end. An
 * edit constraint is then added to the opposite end and the time is
 * measured for adding and removing this constraint, and extracting
 * and executing a constraint satisfaction plan. There are two cases.
 * In case 1, the added constraint is stronger than the stay
 * constraint and values must propagate down the entire length of the
 * chain. In case 2, the added constraint is weaker than the stay
 * constraint so it cannot be accomodated. The cost in this case is,
 * of course, very low. Typical situations lie somewhere between these
 * two extremes.
 */

class DeltaBlue extends BenchmarkBase {

  const DeltaBlue() : super("DeltaBlue");

  static void chainTest(int n) {
    DeltaBlue.planner = new Planner();
    Variable prev = null, first = null, last = null;
    // Build chain of n equality constraints.
    for (int i = 0; i <= n; i++) {
      String name = "v";
      Variable v = new Variable(name, 0);
      if (prev != null)
        new EqualityConstraint(prev, v, Strength.REQUIRED);
      if (i == 0) first = v;
      if (i == n) last = v;
      prev = v;
    }
    new StayConstraint(last, Strength.STRONG_DEFAULT);
    EditConstraint edit = new EditConstraint(first, Strength.PREFERRED);
    List<Constraint> editCollection = new List<Constraint>();
    editCollection.add(edit);
    Plan plan = DeltaBlue.planner.extractPlanFromConstraints(editCollection);
    for (int i = 0; i < 100; i++) {
      first.value = i;
      plan.execute();
      if (last.value != i) {
        DeltaBlue.log("Chain test failed.");
        DeltaBlue.log(last.value.toString());
        DeltaBlue.log(i.toString());
      }
    }
  }

  /**
   * This test constructs a two sets of variables related to each
   * other by a simple linear transformation (scale and offset). The
   * time is measured to change a variable on either side of the
   * mapping and to change the scale and offset factors.
   */
  static void projectionTest(int n) {
    DeltaBlue.planner = new Planner();
    Variable scale = new Variable("scale", 10);
    Variable offset = new Variable("offset", 1000);
    Variable src = null, dst = null;

    List<Variable> dests = new List<Variable>();
    for (int i = 0; i < n; i++) {
      src = new Variable("src", i);
      dst = new Variable("dst", i);
      dests.add(dst);
      new StayConstraint(src, Strength.NORMAL);
      new ScaleConstraint(src, scale, offset, dst, Strength.REQUIRED);
    }
    change(src, 17);
    if (dst.value != 1170) DeltaBlue.log("Projection 1 failed");
    change(dst, 1050);
    if (src.value != 5) DeltaBlue.log("Projection 2 failed");
    change(scale, 5);
    for (int i = 0; i < n - 1; i++) {
      if (dests[i].value != i * 5 + 1000)
        DeltaBlue.log("Projection 3 failed");
    }
    change(offset, 2000);
    for (int i = 0; i < n - 1; i++) {
      if (dests[i].value != i * 5 + 2000)
        DeltaBlue.log("Projection 4 failed");
    }
  }

  static void change(Variable v, int newValue) {
    EditConstraint edit = new EditConstraint(v, Strength.PREFERRED);
    List<EditConstraint> editCollection = new List<EditConstraint>();
    editCollection.add(edit);
    Plan plan = DeltaBlue.planner.extractPlanFromConstraints(editCollection);
    for (int i = 0; i < 10; i++) {
      v.value = newValue;
      plan.execute();
    }
    edit.destroyConstraint();
  }

  void run() {
    Strength.init();
    chainTest(100);
    projectionTest(100);
  }

  static void main() {
    new DeltaBlue().report();
  }

  static Planner planner;

  static void log(String str) {
    print(str);
  }

}
