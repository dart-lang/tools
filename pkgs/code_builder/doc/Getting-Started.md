# Common patterns

## Classes

### Creating a simple class

> ```dart
> class Animal {}
> ```

```dart
new ClassBuilder(
  'Animal',
)
```

### Creating an abstract class with a method

> ```dart
> abstract class Animal {
>   void eat();
> }
> ```

```dart
new ClassBuilder(
  'Animal',
  asAbstract: true,
)..addMethod(
  new MethodBuilder.returnVoid(
    'eat',
    asAbstract: true,
  ),
)
```