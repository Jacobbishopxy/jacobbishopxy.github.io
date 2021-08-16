+++
title = "Rust Std Traits"
description = "Useful traits from the Rust standard library"
date = 2021-08-17

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

[extra]
toc = true
+++

## Intro

Hello everyone :wave:, today I'm going to list several useful and common traits from the Rust standard library. Using [Tour of Rust's Standard Library Traits](https://github.com/pretzelhammer/rust-blog/blob/master/posts/tour-of-rusts-standard-library-traits.md) as my reference. I'm not going through all of it, but to pick some of them that I believe is important to me, and to give more enhanced examples for better comprehension.

## Trait Basics

### Generic Types vs Associated Types

According to the article, the major difference between these two types is:

> The general rule-of-thumb is:
>
> - Use associated types when there should only be a single impl of the trait per type.
> - Use generic types when there can be many possible impls of the trait per type.

That is to say, with associated types a type can only impl it once (otherwise causes compile error). Here is an example that is commonly occurred in my code:

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

Apparently, `BizError` should not use generic type, since it is the only possible 'Error' in the project, while `String`, `Vec<u8>` and `Bytes<'a>` should not use associate type, because they are related to business logic.

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

The only thing we should notice is that a generic type `T` cannot be impl twice, otherwise overlap will make compiler unhappy.

## Auto Traits

Auto traits are an inevitable topic, as long as a programmer wants to compose low level codes rather than just calling APIs from other crates. According to the author:

> Prerequisites:
>
> - Marker Traits: Marker traits are traits that have no trait items. Their job is to "mark" the implementing type as having some property which is otherwise not possible to represent using the type system.
> - Auto Traits: Auto traits are traits that get automatically implemented for a type if all of its members also impl the trait. What "members" means depends on the type, for example: fields of a struct, variants of an enum, elements of an array, items of a tuple, and so on.
> - Unsafe Traits: Traits can be marked unsafe to indicate that impling the trait might require unsafe code.

to be continue...

### Send & Sync

### Sized

## General Traits

## Formatting Traits

## Operator Traits

## Conversion Traits

## Error Handling

## Iteration Traits

## I/O Traits
