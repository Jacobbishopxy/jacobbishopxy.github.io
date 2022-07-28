+++
title = "Impl Index to polars' Series"
description = "A little"
date = 2022-08-01

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

+++

## Intro

Today I would like to talk about a small problem I met in my project, which brought me some brand new idea during the resolution. While trying to select data from Series or DataFrame, the intuitive thought is how to make Rust DataFrame's selection similar to Python's DataFrame? For example, we have `iat`, `at`, `iloc` and `loc` methods in pandas' DataFrame, which represents _accessing integer location scalar_, _accessing a single value for a row/column label pair_, _accessing a group of rows and columns by integer position(s)_, and _accessing a group of rows and columns by label(s)_ respectfully. The first idea comes to me is that implementing `Index` trait for polars series can approach the same effect as pandas DataFrame does.

```rust
pub trait Index<Idx: ?Sized> {
    type Output: ?Sized;

    fn index(&self, index: Idx) -> &Self::Output;
}
```

In accordance with the `Index` trait, we know the associate type `Output` is UnSized and the return value of `index` is a reference of `Output`. However, assuming different types of data are stored in a DataFrame, no wonder that in Python we don't care about the return type, but as known in Rust that returning different types from a function is impossible. Moreover, as polars used Apache Arrow as its memory model, a series in polars actually represents a arrow's array who carries a set of specific type data. Although polars provides us `get` method that returns an enum `AnyValue` type, what if more custom types are required, such as `Uuid`.

Instead, we could probably use either static dispatch (impl trait) or dynamic dispatch (dyn trait) as a workaround (or even worse, by using an `Enum` to wrap all types of data just like polars itself does). So the first problem is that how do we design our own return type.

The second problem is quit annoying: there is no way to return a reference of `Output`, since neither calling `get` method on a series nor calling conversion methods such as `bool` can give us a reference of value(s). Instead, these methods create new values which only allows us to move their ownership. In other words, the lifetime of `&Self::Output` should live as longer as `&self`, but these values returned by polar's methods have shorter lifetime then `&self`.

## Custom Return Type

WIP

## Impl Index

WIP
