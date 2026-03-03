# Foundations Exercise: Small Target/Query Exercises

Run these in order. Each builds on the previous.

## Exercise 1: Simple genrule Chain

```starlark
# In BUCK file - create A -> B -> C dependency chain
# A produces "a.txt", B consumes A and produces "b.txt", C consumes B
```

**Query**: `buck2 cquery "deps(//exercise1:C)"` should show A, B, C.

## Exercise 2: testsof Discovery

Create a test target that depends on a library. Run:

```bash
buck2 cquery "testsof(//exercise2:lib)"
```

Verify the test appears.

## Exercise 3: rdeps for Impact Analysis

Create targets: `lib` <- `service_a`, `service_b`. Run:

```bash
buck2 cquery "rdeps(//exercise3/..., //exercise3:lib)"
```

Both services should appear as reverse deps.

## Exercise 4: kind() Filter

```bash
buck2 cquery "kind(genrule, //...)" --output label
buck2 cquery "kind(rust_binary, //...)" --output label
```

Use to find all rules of a given type across the repo.
