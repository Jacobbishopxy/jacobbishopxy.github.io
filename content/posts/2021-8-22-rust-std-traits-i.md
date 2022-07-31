+++
title = "Rust Std Traits (I)"
description = "Useful traits from the Rust standard library"
date = 2021-08-22

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

[extra]
toc = true
+++

## Intro

Hello everyone :wave:, today I'm going to list several useful and common traits from the Rust standard library. Using [Tour of Rust's Standard Library Traits](https://github.com/pretzelhammer/rust-blog/blob/master/posts/tour-of-rusts-standard-library-traits.md) as my reference, I'm not going through all of it, but to pick some of them that I believe is important, and to give some enhanced examples for better comprehension.

## Trait Basics

### Generic Types vs Associated Types

According to the article, the major difference between these two types is:

> The general rule-of-thumb is:
>
> - Use associated types when there should only be a single impl of the trait per type.
> - Use generic types when there can be many possible impls of the trait per type.

That is to say, with associated types a type can only impl it once (otherwise causes compile error). These might be confusing, but don't worry, here is an example that is commonly occurred in my use case:

```rs
use std::str::Bytes;

fn main() {
    unimplemented!();
}

// T represents many possible impls
pub trait Biz<T> {
    // Error represents only one possible impl
    type Error;

    fn process(&self) -> Result<T, Self::Error>;
}

// ----- below are implementation

// Error is unique, we shall not have another type of error.
// If we do require more error types, don't mess them up into a single business logic.
pub enum BizError {
    ParseError(String),
    UnknownError,
}

// Here is a concrete type of biz logic
pub struct JSON;

// `String` has its own impl
impl Biz<String> for JSON {
    type Error = BizError;

    fn process(&self) -> Result<String, Self::Error> {
        todo!()
    }
}

// So does `Vec<u8>`
impl Biz<Vec<u8>> for JSON {
    type Error = BizError;

    fn process(&self) -> Result<Vec<u8>, Self::Error> {
        todo!()
    }
}

// Here is another concrete type of biz logic
pub struct XML;

// Same as `Biz<String> for JSON`
impl Biz<String> for XML {
    type Error = BizError;

    fn process(&self) -> Result<String, Self::Error> {
        todo!()
    }
}

// But we can have another totally different type `Bytes<'a>` from above
impl<'a> Biz<Bytes<'a>> for XML {
    type Error = BizError;

    fn process(&self) -> Result<Bytes<'a>, Self::Error> {
        todo!()
    }
}
```

Apparently, `BizError` should not use generic type, since it is the only possible 'Error' in the project, while `String`, `Vec<u8>` and `Bytes<'a>` should not belong to associate type, since they are highly related to business logic.

### Generic Blanket Impls

> A generic blanket impl is an impl on a generic type instead of a concrete type.

To explain this, I made an example to illustrate how a general type can automatically grant the power of pre-defined trait (`CRUD` trait), solely implementing the `T` trait (`InnerMap`).

```rs
use std::{collections::HashMap, hash::Hash, iter::FromIterator};

trait InnerMap<K, V> {
    fn store_mut(&mut self) -> &mut HashMap<K, V>;
    fn store_ref(&self) -> &HashMap<K, V>;
}

trait CRUD<K, V> {
    fn create(&mut self, item: HashMap<K, V>);

    fn read(&self, key: K) -> Option<V>;

    fn update(&mut self, item: HashMap<K, V>);

    fn delete(&mut self, key: K);
}

impl<T, K, V> CRUD<K, V> for T
where
    T: InnerMap<K, V>,
    K: Eq + Hash,
    V: Clone,
{
    fn create(&mut self, item: HashMap<K, V>) {
        item.into_iter().for_each(|(k, v)| {
            self.store_mut().insert(k, v);
        })
    }

    fn read(&self, key: K) -> Option<V> {
        self.store_ref().get(&key).cloned()
    }

    fn update(&mut self, item: HashMap<K, V>) {
        self.create(item);
    }

    fn delete(&mut self, key: K) {
        self.store_mut().remove(&key);
    }
}

// ----- below are implementation

// a concrete type with private field
pub struct RedisStore {
    store: HashMap<usize, String>,
}

impl RedisStore {
    fn new() -> Self {
        RedisStore {
            store: HashMap::new(),
        }
    }
}

// CRUD is automatically granted, since `RedisStore` now meets the requirement of `CRUD` trait:
// where clause `T: InnerMap`
impl InnerMap<usize, String> for RedisStore {
    fn store_mut(&mut self) -> &mut HashMap<usize, String> {
        &mut self.store
    }

    fn store_ref(&self) -> &HashMap<usize, String> {
        &self.store
    }
}

fn main() {
    let mut rs = RedisStore::new();

    let data = HashMap::from_iter(vec![(0, "Hello".to_owned()), (1, "World".to_owned())]);

    rs.create(data);

    println!("{:?}", rs.read(1));

    let data = HashMap::from_iter(vec![(0, "Hi".to_owned()), (1, "Jacob".to_owned())]);

    rs.update(data);

    println!("{:?}", rs.read(1));

    rs.delete(1);

    println!("{:?}", rs.read(1));
}
```

The only thing we should notice is that a generic type `T` cannot be impl twice or more, otherwise overlap will make compiler unhappy.

## Auto Traits

Auto traits are an inevitable topic, as long as a programmer wants to compose low level codes rather than just calling APIs from other crates. According to the author:

> Prerequisites:
>
> - Marker Traits: Marker traits are traits that have no trait items. Their job is to "mark" the implementing type as having some property which is otherwise not possible to represent using the type system.
> - Auto Traits: Auto traits are traits that get automatically implemented for a type if all of its members also impl the trait. What "members" means depends on the type, for example: fields of a struct, variants of an enum, elements of an array, items of a tuple, and so on.
> - Unsafe Traits: Traits can be marked unsafe to indicate that impling the trait might require unsafe code.

Briefly, we can have one of conclusion as below:

$$
Marker Traits \in Auto Traits
$$

### Send & Sync

The book [The Rustonomicon](https://doc.rust-lang.org/nomicon/send-and-sync.html) gives us a preciser explanation of Send & Sync:

> - A type is Send if it is safe to send it to another thread.
> - A type is Sync if it is safe to share between threads (T is Sync if and only if &T is Send).

We know that almost all primitives are Send and Sync, but still there are exceptions:

> - raw pointers are neither Send nor Sync (because they have no safety guards).
> - UnsafeCell isn't Sync (and therefore Cell and RefCell aren't).
> - Rc isn't Send or Sync (because the refcount is shared and unsynchronized).

### Sized

Alright here is another fundamental trait that builds up the Rust skyscraper, and it should be firmly mastered.

> If a type is Sized that means its size in bytes is known at compile-time and it's possible to put instances of the type on the stack.

Studying Rust is somehow a history of fighting with `Sized`, because new programmer is always being resulted a compile error says "xxx doesn't have size known at compile time". In order to have a completely comprehension on Sizedness, here is another [article](https://github.com/pretzelhammer/rust-blog/blob/master/posts/sizedness-in-rust.md) written by the author that explains it in detail.

Since `Sized` is an auto trait, it is usually implicitly implemented. For example, see the desugar cases:

> ```rs
> // this generic function...
> fn func<T>(t: T) {}
>
> // ...desugars to...
> fn func<T: Sized>(t: T) {}
>
> // ...which doesn't compile since it doesn't have
> // a known size so we must put it behind a pointer...
> fn func<T: ?Sized>(t: &T) {}
> fn func<T: ?Sized>(t: Box<T>) {}
> ```

Additionally, `?Sized` is treated as a type which can either be Sized or Unsized, and it is the only 'relaxed bound (rather than constrains the type parameter)' in Rust.

## General Traits

### Any

See [this early post](https://jacobbishopxy.github.io/posts/2021-8-16-more-rust-type/) I made for studying `Any` trait. For instance, `Any` can be used with a `Box` pointer and `dyn` keyword to create a heterogenous collection, and later on we can use `downcast_mut` or `downcast_ref` to 'degreed' a `Any` trait object to a concrete object during runtime. Here is a brief example to illustrate what `Any` can do:

```rs
use std::any::Any;

fn main() {
    let mut vec: Vec<Box<dyn Any>> = vec![
        Box::new(0),
        Box::new(String::from("0")),
        Box::new(Point::default()),
    ];

    vec = vec.into_iter().map(map_any).collect();

    for i in vec.iter() {
        println!("{:#?}", i.downcast_ref::<i32>());
    }
}

#[derive(Default)]
struct Point {
    x: i32,
    y: i32,
}

impl Point {
    fn inc(&mut self) {
        self.x += 1;
        self.y += 1;
    }
}

fn map_any(mut any: Box<dyn Any>) -> Box<dyn Any> {
    if let Some(num) = any.downcast_mut::<i32>() {
        *num += 1;
    } else if let Some(string) = any.downcast_mut::<String>() {
        *string += "!";
    } else if let Some(point) = any.downcast_mut::<Point>() {
        point.inc();
    }

    any
}
```

## Formatting Traits

Take a glance at all formatting traits:

> | Trait      | Placeholder | Description                          |
> | ---------- | ----------- | ------------------------------------ |
> | `Display`  | `{}`        | display representation               |
> | `Debug`    | `{:?}`      | debug representation                 |
> | `Octal`    | `{:o}`      | octal representation                 |
> | `LowerHex` | `{:x}`      | lowercase hex representation         |
> | `UpperHex` | `{:X}`      | uppercase hex representation         |
> | `Pointer`  | `{:p}`      | memory address                       |
> | `Binary`   | `{:b}`      | binary representation                |
> | `LowerExp` | `{:e}`      | lowercase exponential representation |
> | `UpperExp` | `{:E}`      | uppercase exponential representation |

### Display & ToString

In general, `std::fmt::Display` is to serialize a type into `String`, for example we can serialize a database connection information struct to a connection string:

```rs
use std::fmt::Display;

fn main() {
    // convert `ConnInfo` to sql connection string
    let ci = ConnInfo::new(
        Driver::Postgres,
        "username",
        "password",
        "localhost",
        5432,
        "database",
    );
    println!("{:?}", ci.to_string());
}

// database type
pub enum Driver {
    Postgres,
    Mysql,
    Sqlite,
}

impl Display for Driver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match &self {
            Driver::Postgres => write!(f, "postgres"),
            Driver::Mysql => write!(f, "mysql"),
            Driver::Sqlite => write!(f, "sqlite"),
        }
    }
}

// connection info
pub struct ConnInfo {
    pub driver: Driver,
    pub username: String,
    pub password: String,
    pub host: String,
    pub port: i32,
    pub database: String,
}

impl ConnInfo {
    pub fn new(
        driver: Driver,
        username: &str,
        password: &str,
        host: &str,
        port: i32,
        database: &str,
    ) -> ConnInfo {
        ConnInfo {
            driver,
            username: username.to_owned(),
            password: password.to_owned(),
            host: host.to_owned(),
            port,
            database: database.to_owned(),
        }
    }
}

impl Display for ConnInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}://{}:{}@{}:{}/{}",
            self.driver, self.username, self.password, self.host, self.port, self.database,
        )
    }
}
```

### Debug

A `Debug` trait is very useful while in development. Any type who has derived or implemented `Debug` can be printed in a well formatted form. Another benefit is using it as an accessory of `dbg!` macro. Notice the only drawback of using `dbg!` is that users need manually remove it while in production.

> Impling Debug for a type also allows it to be used within the dbg! macro which is superior to println! for quick and dirty print logging. Some of its advantages:
>
> - dbg! prints to stderr instead of stdout so the debug logs are easy to separate from the actual stdout output of our program.
> - dbg! prints the expression passed to it as well as the value the expression evaluated to.
> - dbg! takes ownership of its arguments and returns them so you can use it within expressions.

```rs
fn main() {
    let foo = Dimension { x: 1, y: 3, z: 5 };
    println!("{:?}", foo);
    dbg!(foo);
}

#[derive(Debug)]
struct Dimension {
    x: i32,
    y: i32,
    z: i32,
}
```

And resulting:

```txt
Dimension { x: 1, y: 3, z: 5 }
[src/bin/dev.rs:4] foo = Dimension {
    x: 1,
    y: 3,
    z: 5,
}
```

## Operator Traits

Thx to the author for listing out all operator traits:

> | Trait(s)            | Category   | Operator(s)          | Description                  |
> | ------------------- | ---------- | -------------------- | ---------------------------- |
> | `Eq`, `PartialEq`   | comparison | `==`                 | equality                     |
> | `Ord`, `PartialOrd` | comparison | `<`, `>`, `<=`, `>=` | comparison                   |
> | `Add`               | arithmetic | `+`                  | addition                     |
> | `AddAssign`         | arithmetic | `+=`                 | addition assignment          |
> | `BitAnd`            | arithmetic | `&`                  | bitwise AND                  |
> | `BitAndAssign`      | arithmetic | `&=`                 | bitwise assignment           |
> | `BitXor`            | arithmetic | `^`                  | bitwise XOR                  |
> | `BitXorAssign`      | arithmetic | `^=`                 | bitwise XOR assignment       |
> | `Div`               | arithmetic | `/`                  | division                     |
> | `DivAssign`         | arithmetic | `/=`                 | division assignment          |
> | `Mul`               | arithmetic | `\*`                 | multiplication               |
> | `MulAssign`         | arithmetic | `\*=`                | multiplication assignment    |
> | `Neg`               | arithmetic | `-`                  | unary negation               |
> | `Not`               | arithmetic | `!`                  | unary logical negation       |
> | `Rem`               | arithmetic | `%`                  | remainder                    |
> | `RemAssign`         | arithmetic | `%=`                 | remainder assignment         |
> | `Shl`               | arithmetic | `<<`                 | left shift                   |
> | `ShlAssign`         | arithmetic | `<<=`                | left shift assignment        |
> | `Shr`               | arithmetic | `>>`                 | right shift                  |
> | `ShrAssign`         | arithmetic | `>>=`                | right shift assignment       |
> | `Sub`               | arithmetic | `-`                  | subtraction                  |
> | `SubAssign`         | arithmetic | `-=`                 | subtraction assignment       |
> | `Fn`                | closure    | `(...args)`          | immutable closure invocation |
> | `FnMut`             | closure    | `(...args)`          | mutable closure invocation   |
> | `FnOnce`            | closure    | `(...args)`          | one-time closure invocation  |
> | `Deref`             | other      | `\*`                 | immutable dereference        |
> | `DerefMut`          | other      | `\*`                 | mutable dereference          |
> | `Drop`              | other      | -                    | type destructor              |
> | `Index`             | other      | `[]`                 | immutable index              |
> | `IndexMut`          | other      | `[]`                 | mutable index                |
> | `RangeBounds`       | other      | `..`                 | range                        |

### Comparison Traits

#### PartialEq & Eq {#PartialEqNEq}

`#[derive(PartialEq)]` is a very common use case of `PartialEq`. Moreover, an advanced use case is to impl `PartialEq` between two type, in other words, comparison between two different types is achievable.

> Generally, we should only impl equality between different types if they contain the same kind of data and the only difference between the types is how they represent the data or how they allow interacting with the data.

A simple example to illustrate comparison between two types -- comparing `area` between `Circle` and `Square`:

```rs
fn main() {
    let foo = Square::new(4.0, 3.14);
    let bar = Circle::new(2.0);

    println!("{:?}", foo == bar);
}

#[derive(PartialEq)]
struct Circle {
    radius: f32,
}

impl Circle {
    fn new(r: f32) -> Self {
        Circle { radius: r }
    }

    fn area(&self) -> f32 {
        self.radius * self.radius * 3.14
    }
}

#[derive(PartialEq)]
struct Square {
    length: f32,
    width: f32,
}

impl Square {
    fn new(l: f32, w: f32) -> Self {
        Square {
            length: l,
            width: w,
        }
    }

    fn area(&self) -> f32 {
        self.length * self.width
    }
}

impl PartialEq<Circle> for Square {
    fn eq(&self, other: &Circle) -> bool {
        self.area() == other.area()
    }
}
```

Pretty clear hah, so what about `Eq`?

> `Eq` is a marker trait and a subtrait of `PartialEq<Self>`.

Let's see another example under `Hash` topic that illustrates how `PartialEq`, `Eq` and `Hash` work together.

#### Hash {#Hash}

In order to having a customized "Hashable" struct, I made a verbose example that illustrates how to cling `PartialEq`, `Eq` and `Hash` together. Details in comments:

```rs
use std::{collections::HashSet, fmt::Debug, hash::Hash};

fn main() {
    let d1 = Dudu(1);
    let d2 = Dada { v: 1 };
    let d3 = Dada { v: 2 };

    let foo = Biz {
        key: 0,
        val: Box::new(d1), // Dudu
    };

    let bar = Biz {
        key: 0,
        val: Box::new(d2), // Dada
    };

    let quz = Biz {
        key: 0,
        val: Box::new(d3), // Dada
    };

    let mut collection = HashSet::new();

    collection.insert(foo);
    collection.insert(bar);

    // notice here, `foo` and `bar` are treated as a same value, since their val has
    // the same `.id()` result, so hashMap won't be updated
    println!("{:?}", collection); // {Biz { key: 0, val: > 1 < }}

    collection.insert(quz);

    // hashMap has been updated, because `quz`'s `val` has a different `.id()` result
    println!("{:?}", collection); // {Biz { key: 0, val: > 1 < }, Biz { key: 0, val: > 2 < }}
}

// mock trait, we will use it to create a trait object
trait MockT {
    // the only way to identify a trait object is by this method (of cuz this is mocking)
    fn id(&self) -> usize;
}

// impl `PartialEq`
impl PartialEq for dyn MockT {
    fn eq(&self, other: &Self) -> bool {
        self.id() == other.id()
    }
}

// impl `Eq`, marker trait
impl Eq for dyn MockT {}

// for println
impl Debug for dyn MockT {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "> {} <", self.id())
    }
}

// mocking a business logic struct, which consist of a key of `i32` and a val of trait object.
#[derive(Eq, Debug)]
struct Biz {
    key: i32,
    val: Box<dyn MockT>,
}

impl PartialEq for Biz {
    fn eq(&self, other: &Self) -> bool {
        // again, calling `.id()` method is the only way to discern trait objects
        self.key == other.key && self.val.id() == other.val.id()
    }
}

// impl `Hash` so that later on, we can use `Biz` in `HashMap` or `HashSet`
impl Hash for Biz {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        state.write_i32(self.key);
        state.write_usize(self.val.id());
    }
}

// concrete struct #1 who impled `MockT`
struct Dudu(usize);

impl MockT for Dudu {
    fn id(&self) -> usize {
        self.0
    }
}

// concrete struct #2 who impled `MockT`
struct Dada {
    v: usize,
}

impl MockT for Dada {
    fn id(&self) -> usize {
        self.v
    }
}
```

#### PartialOrd & Ord

Generally, `PartialOrd` is used for type comparison, whereas comparison between two different types is eligible as well. Let us first take a glimpse at the `PartialOrd` trait (simplified and documentations removed):

> ```rs
> pub trait PartialOrd<Rhs: ?Sized = Self>: PartialEq<Rhs> {
>     fn partial_cmp(&self, other: &Rhs) -> Option<Ordering>;
>
>     fn lt(&self, other: &Rhs) -> bool;
>
>     fn le(&self, other: &Rhs) -> bool;
>
>     fn gt(&self, other: &Rhs) -> bool;
>
>     fn ge(&self, other: &Rhs) -> bool;
> }
> ```

The `Rhs` generic type parameter, which denotes a short for "right hand side", has a `?Sized` trait bound for the implementor type itself. Although directly deriving `PartialOrd` to a custom type is the common use case, we might want custom implementation occasionally. Take `Circle` and `Square` (defined in [PartialEq & Eq](#PartialEqNEq)) as an example to see comparison between two custom types:

```rs

// ... `Circle` and `Square` are defined in 'PartialEq & Eq' section

impl PartialOrd<Circle> for Square {
    fn partial_cmp(&self, other: &Circle) -> Option<Ordering> {
        let x = self.area();
        let y = other.area();

        if x == y {
            return Some(Ordering::Equal);
        }

        if x > y {
            Some(Ordering::Greater)
        } else {
            Some(Ordering::Less)
        }
    }
}

fn main() {
    let foo = Square::new(4.0, 3.14);
    let bar = Circle::new(2.0);

    println!("{:?}", foo > bar);    // false
}
```

Moving on to the `Ord` trait.

> `Ord` is a subtrait of `Eq` and `PartialOrd<Self>`.

The example I gave is then not suitable for `Ord`, because what we implemented is `impl PartialOrd<Circle> for Square`, which implies the generic type in `PartialOrd` is `Square` instead of `Circle` (as `Self`). Despite of this we can still use dynamic dispatching to write an example. Take `MockT` trait from above ([MockT](#Hash)), here I simplified the code and add `impl PartialOrd` and `impl Ord` to `MockT` trait:

```rs
use std::{cmp::Ordering, fmt::Debug};

fn main() {
    let d1 = Dudu(2);
    let d2 = Dada { v: 3 };
    let d3 = Dada { v: 1 };

    let mut collection: Vec<Box<dyn MockT>> = vec![Box::new(d1), Box::new(d2), Box::new(d3)];

    println!("{:?}", collection); // [> 2 <, > 3 <, > 1 <]

    collection.sort();

    println!("{:?}", collection); // [> 1 <, > 2 <, > 3 <]
}

// mock trait, we will use it to create a trait object
trait MockT {
    // the only way to identify a trait object is by this method (of cuz this is mocking)
    fn id(&self) -> usize;
}

// impl `PartialEq`
impl PartialEq for dyn MockT {
    fn eq(&self, other: &Self) -> bool {
        self.id() == other.id()
    }
}

// impl `PartialOrd`
impl PartialOrd for dyn MockT {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        let x = self.id();
        let y = other.id();

        if x == y {
            return Some(Ordering::Equal);
        }

        if x > y {
            Some(Ordering::Greater)
        } else {
            Some(Ordering::Less)
        }
    }
}

// impl `Ord`
impl Ord for dyn MockT {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        match self.id().cmp(&other.id()) {
            Ordering::Equal => self.cmp(other),
            ordering => ordering,
        }
    }
}

// impl `Eq`, marker trait
impl Eq for dyn MockT {}

// for println
impl Debug for dyn MockT {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "> {} <", self.id())
    }
}

// concrete struct #1 who impled `MockT`
struct Dudu(usize);

impl MockT for Dudu {
    fn id(&self) -> usize {
        self.0
    }
}

// concrete struct #2 who impled `MockT`
struct Dada {
    v: usize,
}

impl MockT for Dada {
    fn id(&self) -> usize {
        self.v
    }
}
```

Above we made a demo for trait object ordering, its main idea is to sort dynamic types in an array, such as `Vec` and `VecDeque`.

### Arithmetic Traits

Thx again:

> | Trait(s)       | Category   | Operator(s) | Description               |
> | -------------- | ---------- | ----------- | ------------------------- |
> | `Add`          | arithmetic | `+`         | addition                  |
> | `AddAssign`    | arithmetic | `+=`        | addition assignment       |
> | `BitAnd`       | arithmetic | `&`         | bitwise AND               |
> | `BitAndAssign` | arithmetic | `&=`        | bitwise assignment        |
> | `BitXor`       | arithmetic | `^`         | bitwise XOR               |
> | `BitXorAssign` | arithmetic | `^=`        | bitwise XOR assignment    |
> | `Div`          | arithmetic | `/`         | division                  |
> | `DivAssign`    | arithmetic | `/=`        | division assignment       |
> | `Mul`          | arithmetic | `\*`        | multiplication            |
> | `MulAssign`    | arithmetic | `\*=`       | multiplication assignment |
> | `Neg`          | arithmetic | `-`         | unary negation            |
> | `Not`          | arithmetic | `!`         | unary logical negation    |
> | `Rem`          | arithmetic | `%`         | remainder                 |
> | `RemAssign`    | arithmetic | `%=`        | remainder assignment      |
> | `Shl`          | arithmetic | `<<`        | left shift                |
> | `ShlAssign`    | arithmetic | `<<=`       | left shift assignment     |
> | `Shr`          | arithmetic | `>>`        | right shift               |
> | `ShrAssign`    | arithmetic | `>>=`       | right shift assignment    |
> | `Sub`          | arithmetic | `-`         | subtraction               |
> | `SubAssign`    | arithmetic | `-=`        | subtraction assignment    |

Since all the arithmetic traits' implementation are alike to comparison traits, further elaboration is omitted here.

### Closure Traits

> | Trait(s) | Category | Operator(s) | Description                  |
> | -------- | -------- | ----------- | ---------------------------- |
> | `Fn`     | closure  | `(...args)` | immutable closure invocation |
> | `FnMut`  | closure  | `(...args)` | mutable closure invocation   |
> | `FnOnce` | closure  | `(...args)` | one-time closure invocation  |

As mentioned:

> The only types we can create which impl these traits are closures.

And as THE BOOK says:

> Things that impl `FnOnce` can mutate and consume (take ownership of) the values they close over when they run, and so can only be run once.
> Things that impl `FnMut` can mutate the values they close over when they run, but not consume them.
> Things that impl `Fn` can only immutably borrow variables when they run.

TODO: example

### Other Traits

| Trait(s)      | Category | Operator(s) | Description           |
| ------------- | -------- | ----------- | --------------------- |
| `Deref`       | other    | `\*`        | immutable dereference |
| `DerefMut`    | other    | `\*`        | mutable dereference   |
| `Drop`        | other    | -           | type destructor       |
| `Index`       | other    | `[]`        | immutable index       |
| `IndexMut`    | other    | `[]`        | mutable index         |
| `RangeBounds` | other    | `..`        | range                 |

Due to the limited space, I've split this post into two parts. Please click the link below to see the second part.
