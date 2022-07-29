+++
title = "Impl Index for polars' Series"
description = "A little"
date = 2022-08-01

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

+++

## Intro

Today I would like to talk about a small problem I met in my project, and the inspired thoughts through the whole working process. While trying to select data from Series or DataFrame, the intuitive thought is how to make Rust DataFrame's selection similar to Python's DataFrame? For example, we have `iat`, `at`, `iloc` and `loc` methods in pandas' DataFrame, which represents _accessing integer location scalar_, _accessing a single value for a row/column label pair_, _accessing a group of rows and columns by integer position(s)_, and _accessing a group of rows and columns by label(s)_ respectfully. The first idea came to me is that implementing `Index` trait for polars series can approach the same effect as pandas DataFrame does. As a syntactic sugar of `foo.index(index)`, `Index` provide us a simple way to get an indexed of value from a variable.

```rust
pub trait Index<Idx: ?Sized> {
    type Output: ?Sized;

    fn index(&self, index: Idx) -> &Self::Output;
}
```

In accordance with the `Index` trait, we know the associate type `Output` is UnSized and the return value of `index` is a reference of `Output`. However, assuming different types of data are stored in a DataFrame, no wonder that in Python we don't care about the return type, but as known in Rust that returning different types from a function is impossible. Moreover, as polars used Apache Arrow as its memory model, a series in polars actually represents a arrow's array who carries a set of specific type data. Although polars provides us `get` method that returns an enum `AnyValue` type, what if more custom types are required, such as `Uuid`.

Instead, we could probably use either static dispatching (impl trait) or dynamic dispatching (dyn trait) as a workaround (or even worse, by using an `Enum` to wrap all types of data just like polars itself does). So the first problem is how do we design our own return type.

The second problem is quite annoying: there is no way to return a reference of `Output`, since neither calling `get` method on a series nor calling conversion methods such as `bool` can give us a reference of value(s). Instead, these methods create new values which only allows us to move their ownership. In other words, the lifetime of `&Self::Output` should live as longer as `&self`, but these values returned by polar's methods have shorter lifetime then `&self`.

## Custom Return Type

Designing a custom return type for `Output` is the first thing we should consider. As mentioned above, we need a trait who represents the interface of our own type, and then implement this trait for all primitive types and custom type, so that finally we could treat `Output` as a trait object.

```rust
trait MyValueTrait: Debug {
    fn dtype(&self) -> &'static str;
}

impl MyValueTrait for bool {
    fn dtype(&self) -> &'static str {
        "bool"
    }
}

impl MyValueTrait for i64 {
    fn dtype(&self) -> &'static str {
        "i64"
    }
}

#[derive(Debug)]
struct Null;

impl MyValueTrait for Null {
    fn dtype(&self) -> &'static str {
        "null"
    }
}
```

Apparently, in this case, `impl Trait` (static dispatch) is not Sized, for instance we have struct `MyGenericValue<T: MyValueTrait>(T)`, and `MyGenericValue(true)`'s size is not equal to `MyGenericValue(1i64)` (try this `assert_ne!(std::mem::size_of_val(&v1), std::mem::size_of_val(&v2))`). Hence, `dyn Trait` is the only thing left for us.

The next step is to choose `&dyn Trait` or `Box<dyn Trait>`, since we cannot use a bare `dyn Trait`. The former one means a reference, but when implementing `Index`, there is no way to hold the original variable which is also UnSized. For instance, though `&true as &dyn MyValueTrait` and `&1i64 as &dyn MyValueTrait` have the same size, `true` and `1i64` are not the same. As a result, I choose to use a newtype of `Box<dyn MyValueTrait>`:

```rust
#[derive(Debug)]
struct MyValue(Box<dyn MyValueTrait>);

impl AsRef<MyValue> for Box<dyn MyValueTrait> {
    fn as_ref(&self) -> &MyValue {
        unsafe { std::mem::transmute(self) }
    }
}

#[test]
fn my_value_as_ref() {
    let dv = Box::new(false) as Box<dyn MyValueTrait>;

    let dvr: &MyValue = dv.as_ref();

    println!("{:?}", dvr);
}
```

Do not afraid of the unsafe code, I would replace them all later on. The reason why I use a newtype instead of `Box<dyn MyValueTrait>` directly is the capacity of implementing traits:

```rust
impl From<bool> for MyValue {
    fn from(v: bool) -> Self {
        Self(Box::new(v))
    }
}

impl From<i64> for MyValue {
    fn from(v: i64) -> Self {
        Self(Box::new(v))
    }
}

impl From<Null> for MyValue {
    fn from(v: Null) -> Self {
        Self(Box::new(v))
    }
}
```

That's it. The first part of the design is pretty simple, and the only problem remained is the unsafe code which will be solved in the last section.

## Impl Index

WIP

[unsafe code](https://github.com/Jacobbishopxy/jotting/blob/master/polars-prober/src/unsafe_index.rs)

## Safe Code

[code](https://github.com/Jacobbishopxy/jotting/blob/master/polars-prober/src/index.rs)
