+++
title = "Lambda Comparison"
description = "C++ vs. Rust"
date = 2022-11-01
updated = 2022-11-03

[taxonomies]
categories = ["Post"]
tags = ["C++", "Rust"]

[extra]
toc = true
+++

While working on a trivial project, a simple idea hits on me: what's the difference between C++'s lambda and Rust's closure? Having an explicit listing may give me a better cognition.

Here is a quick summary of today's topic:

| function                                                                                       | C++'s Concept | Rust's Concept | Major Variety |
| ---------------------------------------------------------------------------------------------- | ------------- | -------------- | ------------- |
| [lambda_and_fn_ptr](@/posts/2022-11-01-lambda-comparison.md#lambda_and_fn_ptr)                 | ✔️            | ✔️             |               |
| [simple_lambda](@/posts/2022-11-01-lambda-comparison.md#simple_lambda)                         | ✔️            | ✔️             | ✔️            |
| [passing_lambda_to_fn](@/posts/2022-11-01-lambda-comparison.md#passing_lambda_to_fn)           | ✔️            | ✔️             |               |
| [generic_lambda](@/posts/2022-11-01-lambda-comparison.md#generic_lambda)                       | ✔️            | ✔️             |               |
| [simple_capture](@/posts/2022-11-01-lambda-comparison.md#simple_capture)                       | ✔️            | ✔️             |               |
| [mutable_capture](@/posts/2022-11-01-lambda-comparison.md#mutable_capture)                     | ✔️            | ✔️             | ✔️            |
| [reference_capture](@/posts/2022-11-01-lambda-comparison.md#reference_capture)                 | ✔️            | ✔️             | ✔️            |
| [ownership_capture](@/posts/2022-11-01-lambda-comparison.md#ownership_capture)                 | ✔️            | ✔️             | ✔️            |
| [mixing_capture](@/posts/2022-11-01-lambda-comparison.md#mixing_capture)                       | ✔️            | ✔️             |               |
| [default_value_capture](@/posts/2022-11-01-lambda-comparison.md#default_value_capture)         | ✔️            | ❌             |               |
| [default_reference_capture](@/posts/2022-11-01-lambda-comparison.md#default_reference_capture) | ✔️            | ❌             |               |
| [default_mixing_capture](@/posts/2022-11-01-lambda-comparison.md#default_mixing_capture)       | ✔️            | ❌             |               |
| [init_var_capture](@/posts/2022-11-01-lambda-comparison.md#init_var_capture)                   | ✔️            | ❌             |               |
| [copy_lambda](@/posts/2022-11-01-lambda-comparison.md#copy_lambda)                             | ✔️            | ❌             |               |
| [copy_ref_lambda](@/posts/2022-11-01-lambda-comparison.md#copy_ref_lambda)                     | ✔️            | ❌             |               |

## lambda_and_fn_ptr {#lambda_and_fn_ptr}

Function pointer is not necessary a key difference, though they can be passed as a parameter to a function both in C++ and Rust. However, in C++, rather than using a function pointer to hold a non-capturing lambda (as its odd syntax), prefer using a list initialization with lambda syntax.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void lambda_and_fn_ptr() {
  int (*lbd)(int){[](int i) { return i * 2; }};

  std::cout << lbd(2) << std::endl;
  std::cout << lbd(3) << std::endl;
}
```

Unlike C++, no need to explicit declare a pointer with function type. Instead, a named variable with function pointer type is a pointer variable. Identically, C++'s function pointer only works for non-capturing lambda, and Rust function pointer type can only be created for non-capturing closures.

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn lambda_and_fn_ptr() {
    let mul = |i: i32| i * 2;

    type M = fn(i32) -> i32;

    let lbd: M = mul;

    println!("{:?}", lbd(2));
    println!("{:?}", lbd(3));
}
```

## simple_lambda {#simple_lambda}

In both C++ and Rust, a simple lambda/closure is non-capturing. Note that `simple_lambda2` in C++, instead of using `auto` keyword, use a type deduction for `std::function`, and prior C++17, explicit type `std::function<(int)>` is required.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void simple_lambda1() {
  auto lbd{[](int i) { return i * 3; }};

  std::cout << lbd(2) << std::endl;
}

void simple_lambda2() {
  std::function lbd{[](int i) { return i * 4; }};

  std::cout << lbd(2) << std::endl;
}
```

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn simple_lambda1() {
    let lbd = |i: i32| i * 3;

    println!("{:?}", lbd(2));
}
```

## passing_lambda_to_fn {#passing_lambda_to_fn}

In C++, passing a function point who represents a lambda expression, whereas in Rust, passing a pointer function type variable.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void passing_lambda_to_fn(const std::function<int(int)>& fn) {
  constexpr int input = 2;

  std::cout << fn(input) << std::endl;
}
```

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn passing_lambda_to_fn(f: fn(i32) -> i32) {
    let input = 2;

    println!("{:?}", f(input));
}
```

## generic_lambda {#generic_lambda}

In C++, there are either `auto` keyword or function template can serve generic lambda.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void generic_lambda0(auto value) {
  auto print{[](auto v) { std::cout << "value: " << v << std::endl; }};

  print(value);
}

template <typename T> void generic_lambda1(T value) {
  auto print{[](T v) { std::cout << "value: " << v << std::endl; }};

  print(value);
}
```

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn generic_lambda<T: Debug>(value: T) {
    let lbd = |v| {
        println!("value: {v:?}");
    };

    lbd(value);
}
```

## simple_capture {#simple_capture}

The first biggest difference happens while calling `simple_capture`: although it looks like the same when capturing a variable is actually clone this variable, Rust acts differently on account of `Copy`/`Clone` trait implementation.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void simple_capture() {
  std::string data{"halloween has come!"};

  auto rise_headless_horseman{[data](std::string_view str) { std::cout << data << " " << str; }};

  const std::string_view greet{
      "Prepare yourselves, the bells have tolled! Shelter your weak, your young and your old! Each "
      "of you shall pay the final sum. Cry for mercy, the reckoning has come!"};

  rise_headless_horseman(greet);
}
```

As shown below, the only difference between `simple_capture2` and `simple_capture3` is the `#[derive(Clone)]` on `struct MyStr(String);`. In short, a variable who does not implemented `copy` or `clone` trait will trigger move semantics, and its ownership will be passed into the closure who captured it.

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn simple_capture1() {
    let data = String::from("halloween has come!");

    let rise_headless_horseman = |s| {
        println!("{data:?} {s:?}",);
    };

    const GREET: &str = "Prepare yourselves, the bells have tolled! Shelter your weak, your young and your old! Each of you shall pay the final sum. Cry for mercy, the reckoning has come!";

    rise_headless_horseman(GREET);

    let _check_ownership = data.into_bytes();
}

fn simple_capture2() {
    struct MyStr(String);

    impl MyStr {
        fn turn(self) -> String {
            self.0
        }
    }

    let data = MyStr(String::from("halloween coming soon"));

    let prepare_pumpkins = |s| {
        println!("{:?} -> {s}", data.0);
    };

    const G: &str = "Carving pumpkins";

    prepare_pumpkins(G);

    // compile error here! since data has been moved into `prepare_pumpkins`
    // let _check_ownership = data.turn();
}

fn simple_capture3() {
    #[derive(Clone)]
    struct MyStr(String);

    impl MyStr {
        fn turn(self) -> String {
            self.0
        }
    }

    let data = MyStr(String::from("halloween coming soon"));

    let prepare_pumpkins = |s| {
        println!("{:?} -> {s}", data.0);
    };

    const G: &str = "Carving pumpkins";

    prepare_pumpkins(G);

    // Ownership hasn't been take until now.
    // Clone has been made while compiling `prepare_pumpkins` on account of `#[derive(Clone)]`
    let _check_ownership = data.turn();
}
```

## mutable_capture {#mutable_capture}

The second mainly difference is right here: C++'s mutable capture (a `mutable` keyword after parentheses) means granting mutability to all captured variables (remove the default `const` capturing limitation), and in fact these variables are still cloned from their original statements; on the other hands, Rust's mutable capture is done by mutable reference capture.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void mutable_capture() {
  int quiver{8};

  auto shoot{[quiver]() mutable {
    --quiver;
    std::cout << "Arrows left: " << quiver << std::endl;
  }};

  shoot();
  shoot();
  shoot();
}
```

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn mutable_capture1() {
    let mut quiver = 8;

    let mut shoot = || {
        // let q = &mut quiver;
        quiver -= 1;
        println!("Arrows left {quiver:?}");
    };

    shoot();
    shoot();
    shoot();

    println!("Check the rest: {quiver:?}");
}

fn mutable_capture2() {
    struct Quiver(i32);

    impl Quiver {
        fn shoot(&mut self) {
            self.0 -= 1;
        }

        fn check(&self) -> i32 {
            self.0
        }
    }

    let mut quiver = Quiver(8);

    let mut shoot = || {
        // let q = &mut quiver;
        // q.shoot();
        quiver.shoot();
        println!("Arrows left {:?}", quiver.check());
    };

    shoot();
    shoot();
    shoot();

    println!("Check the rest: {:?}", quiver.check());
}
```

## reference_capture {#reference_capture}

The third difference is about capturing by reference. Capture by reference in C++ is done by a `&` operator before captured variable, and since C++'s reference is mutable, it can be used for value change. Yet reference in Rust means immutable reference by default. Hence, value change manipulation can only done by a `Rc<RefCell<T>>` and etc.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void reference_capture() {
  int magazine{120};

  auto fire{[&magazine]() {
    magazine -= 10;
    std::cout << "Bullets left: " << magazine << std::endl;
  }};

  fire();
  fire();
  fire();
}
```

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn reference_capture1() {
    // let mut quiver = 8;
    let quiver = 8;

    let check = || {
        println!("Arrows check {:?}", &quiver);
    };

    check();

    // compile error: violate borrow checker
    // quiver -= 1;
    // check();
}

fn reference_capture2() {
    use std::cell::RefCell;
    use std::rc::Rc;

    let quiver = Rc::new(RefCell::new(8));

    let check = || {
        // Note: a `.clone()` on `Rc` only clones a memory address
        println!("Arrows check {:?}", quiver.clone().borrow());
    };

    check();

    *quiver.borrow_mut() -= 1;

    check();
}
```

## ownership_capture {#ownership_capture}

The fourth difference is the moving range: C++ is moved by specified variable and Rust is moved by all captured variables. C++ should `#include<memory>` first, then call by `std::move()`, and Rust use keyword `move` in front of closure.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void ownership_capture() {
  int quiver{8};

  auto shoot{[q = std::move(quiver)]() mutable {
    // quiver has been moved
    --q;
    std::cout << "Arrows left: " << q << std::endl;
  }};

  shoot();
  shoot();
}
```

{% styled_block(class="color-rust") %}
Rust
{% end %}

```rs
fn ownership_capture1() {
    let mut quiver = 8;

    let mut shoot = move || {
        quiver -= 1;
        println!("Arrows left {quiver:?}");
    };

    shoot();
    shoot();
    shoot();

    // ⚠️ watch out! this still prints `8`, because all the primitive type in Rust has `Copy` implemented!
    println!("Check the rest {quiver:?}");
}

fn ownership_capture2() {
    struct Quiver(i32);

    impl Quiver {
        fn shoot(&mut self) {
            self.0 -= 1;
        }

        fn check(&self) -> i32 {
            self.0
        }
    }

    let mut quiver = Quiver(8);

    let mut shoot = move || {
        quiver.shoot();
        println!("Arrows left {:?}", quiver.check());
    };

    shoot();
    shoot();
    shoot();

    // compile error here! Since `quiver` has been captured by ownership,
    // which in other words `quiver` is owned by the closure.
    // println!("Check the rest {:?}", quiver.check());
}
```

## mixing_capture {#mixing_capture}

Mixing capture is not so that important in Rust, as its capturing mechanism is actually differed by `copy`/`clone`, immutable/mutable reference which is already shown above (hence Rust's example is omitted in here).

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void mixing_capture() {
  // capture by reference, by this means, players aiming one single target
  int boss{100};
  // capture by value, by this means, represents different players
  int player{10};

  auto melee{[&boss, player](bool offensive) {
    static int p{player};
    char direction{'>'};
    if (offensive) {
      boss -= 10;
      direction = '<';
    } else {
      p -= 1;
      direction = '>';
    }

    std::cout << "boss[ " << boss << " ] " << direction << " melee[ " << p << " ]" << std::endl;
  }};

  auto range{[&boss, player](bool offensive) {
    static int p{player};
    char direction{'>'};
    if (offensive) {
      boss -= 20;
      direction = '<';
    } else {
      p -= 3;
      direction = '>';
    }

    std::cout << "boss[ " << boss << " ]  " << direction << "  range[ " << p << " ]" << std::endl;
  }};

  melee(false);
  melee(false);
  range(true);
  range(true);
  melee(true);
  range(false);
}
```

## default_value_capture {#default_value_capture}

The fifth difference is about default value/reference capture. There is no such kink of mechanism in Rust. The default value capture means "capture by value without explicit declaring captured variables".

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void default_value_capture() {
  int player{10};

  auto lbd{[=]() {
    // buffed by a holy priest
    std::cout << "Player get buffed: " << player + 5 << std::endl;
  }};

  lbd();

  std::cout << "The original player: " << player << std::endl;
}
```

## default_reference_capture {#default_reference_capture}

The reference capture means "capture by reference without explicit declaring captured variables".

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void default_reference_capture() {
  int boss{100};

  auto lbd{[&]() {
    // attacked by a hunter's aimed shot
    boss -= 20;
    std::cout << "Boss get hit: " << boss << std::endl;
  }};

  lbd();

  std::cout << "The original boss: " << boss << std::endl;
}
```

## default_mixing_capture {#default_mixing_capture}

A short snippet that demonstrates default mixing capture:

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
// value capture a & b, reference capture c
[a, b, &c](){};

// reference capture c, value capture the rest
[=, &c](){};

// value capture a, reference capture the rest
[&, a](){};

// ⚠️ illegal, already reference captured all
[&, &c](){};

// ⚠️ illegal, already value captured all
[=, a](){};

// ⚠️ illegal, captured a twice
[a, &b, &a](){};

// ⚠️ illegal, default capture should always at the first
[armor, &](){};

// a full example
void default_mixing_capture() {
  int boss_health{100};
  int player_health{10};

  const int boss_dmg{3};
  const int player_dmg{1};

  // boss -> player
  auto boss_player{[=, &player_health]() {
    player_health -= boss_dmg;
    std::cout << "The boss has made " << boss_dmg << " to the player, and the player has left " << player_health
              << " health!" << std::endl;
  }};

  // player -> boss
  auto player_boss{[&, player_dmg]() {
    boss_health -= player_dmg;
    std::cout << "The play has made " << player_dmg << " to the boss, and the boss has left " << boss_health
              << " health!" << std::endl;
  }};

  boss_player();
  player_boss();
  player_boss();
  player_boss();
  boss_player();
  player_boss();
}
```

## init_var_capture {#init_var_capture}

The sixth difference. There is no such kink of mechanism in Rust.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void init_var_capture() {
  int life{3};

  // &o is initialzed as life's reference
  // d is initialzed from cloned life
  auto double_life{[&o = life, d{life * 2}]() {
    o *= 2;
    std::cout << "1. Doubled life is " << o << std::endl;
    std::cout << "2. Doubled life is " << d << std::endl;
  }};

  // print 6, 6
  double_life();
  // print 12, 6
  // this is because `d{life * 2}` only initialzed once (when the first call is defined)
  double_life();

  // 12, no doubt `o *= 2;` has been called twice
  std::cout << "The original life has been changed to: " << life << std::endl;
}
```

## copy_lambda {#copy_lambda}

Additionally, in C++ lambda is a an object, which can be copy and modified. Although a `mutable` keyword has been used in here, `stage` is still captured by value (cloned). Hence, `stage` turns into a stateful variable who has been stored inside the lambda. It turns out, whenever a clone has been made upon `step_forward`, its state (`stage`) would have been cloned as well.

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
void copy_lambda() {
  int stage{0};

  auto step_forward{[stage]() mutable {
    stage++;
    std::cout << "step forward: " << stage << std::endl;
  }};

  step_forward(); // stage -> 1

  auto another_sf{step_forward}; // stage: 1

  step_forward(); // stage -> 2
  another_sf();   // stage -> 2

  // no doubt, stage is still `0` right here
  std::cout << "final stage: " << stage << std::endl;
}
```

## copy_ref_lambda {#copy_ref_lambda}

One more extra stuff:

{% styled_block(class="color-cpp") %}
C++
{% end %}

```cpp
// `auto&` means type deduction of the argument must be a reference
// by the later call, it turns out to be `std::function<void()>&`
void copy_invoke(const auto& fn) { fn(); }

/**
 * @brief copy lambda by reference
 *
 * type `std::reference_wrapper` created by `std::ref`
 */
void copy_ref_lambda() {
  int stage{0};

  auto step_forward{[stage]() mutable {
    // stage is modified
    std::cout << ++stage << std::endl;
  }};

  copy_invoke(std::ref(step_forward)); // stage -> 1
  copy_invoke(std::ref(step_forward)); // stage -> 2
  copy_invoke(std::ref(step_forward)); // stage -> 3
}
```

Check my [Github page](https://github.com/Jacobbishopxy/jotting/tree/master/lambda-comparison) to see the code, and leave me a comment if you have any suggestion.
