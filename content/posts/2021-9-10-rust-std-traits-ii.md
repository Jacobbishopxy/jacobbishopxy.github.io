+++
title = "Rust Std Traits (II)"
description = "Useful traits from the Rust standard library"
date = 2021-09-10

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

[extra]
toc = true
+++

Let's continue our exploration of the Rust standard traits.

## Error Handling

As I've already played with Error and Result so much, I'm going to introduce three crates that are useful for dealing with errors. They are [`thiserror`](https://crates.io/crates/thiserror), [`anyhow`](https://crates.io/crates/anyhow) and [`snafu`](https://crates.io/crates/snafu).

Below is a simple example of combining `thiserror` and `anyhow` to solve a customized error.

```rs
//! Error Handling

use anyhow::{anyhow, Context, Result};
use thiserror::Error;

use serde::Deserialize;
use serde_json::from_str;

#[allow(dead_code)]
#[derive(Deserialize, Debug)]
struct ClusterMap {
    name: String,
    group: i32,
}

/*
1. anyhow::Result + anyhow::Context
*/

#[allow(dead_code)]
fn get_cluster_info(path: &str) -> Result<ClusterMap> {
    let config =
        std::fs::read_to_string(path).with_context(|| format!("Failed to read from {}", path))?;
    let map = from_str(&config);

    match map {
        Ok(map) => Ok(map),
        Err(e) => Err(anyhow!("Failed to parse config: {}", e)),
    }
}

#[test]
fn test_get_cluster_info() {
    let cm = get_cluster_info("./mock/cluster_map.json");
    println!("{:?}", cm);
}

/*
2. thiserror::Error
*/

#[allow(dead_code)]
#[derive(Error, Debug)]
pub enum ClusterMapError {
    #[error("Invalid range of range (expected in 0-100), got {0}")]
    InvalidGroup(i32),
}

#[allow(dead_code)]
impl ClusterMap {
    fn validate(self) -> Result<Self> {
        if self.group < 0 || self.group > 100 {
            Err(ClusterMapError::InvalidGroup(self.group).into())
        } else {
            Ok(self)
        }
    }
}

#[allow(dead_code)]
fn get_cluster_info_pro(path: &str) -> Result<ClusterMap> {
    let config =
        std::fs::read_to_string(path).with_context(|| format!("Failed to read from {}", path))?;
    let map: ClusterMap = from_str(&config)?;
    let map = map.validate()?;
    Ok(map)
}

#[test]
fn test_get_cluster_info_pro() {
    let _ = match get_cluster_info_pro("./mock/cluster_map.json") {
        Ok(cm) => println!("{:?}", cm),
        Err(e) => println!("{:?}", e),
    };
}
```

TODO: `snafu` example

## Conversion Traits

### From/Into & TryFrom/TryInto

Simple and useful:

```rs
use std::convert::TryFrom;

enum JsonValue {
    Number(f64),
    Integer(i64),
    String(String),
}

impl From<f64> for JsonValue {
    fn from(v: f64) -> Self {
        JsonValue::Number(v)
    }
}

impl From<f32> for JsonValue {
    fn from(v: f32) -> Self {
        JsonValue::Number(v.into())
    }
}

impl From<i32> for JsonValue {
    fn from(v: i32) -> Self {
        JsonValue::Integer(v.into())
    }
}

impl From<i16> for JsonValue {
    fn from(v: i16) -> Self {
        JsonValue::Integer(v.into())
    }
}

impl From<i8> for JsonValue {
    fn from(v: i8) -> Self {
        JsonValue::Integer(v.into())
    }
}

impl From<&str> for JsonValue {
    fn from(v: &str) -> Self {
        JsonValue::String(v.to_owned())
    }
}

impl From<String> for JsonValue {
    fn from(v: String) -> Self {
        JsonValue::String(v)
    }
}

enum MyError {
    ParseError,
}

impl TryFrom<JsonValue> for String {
    type Error = MyError;

    fn try_from<'a>(value: JsonValue) -> Result<Self, Self::Error> {
        match value {
            JsonValue::String(s) => Ok(s),
            _ => Err(MyError::ParseError),
        }
    }
}

impl TryFrom<JsonValue> for i64 {
    type Error = MyError;

    fn try_from(value: JsonValue) -> Result<Self, Self::Error> {
        match value {
            JsonValue::Integer(f) => Ok(f),
            _ => Err(MyError::ParseError),
        }
    }
}

impl TryFrom<JsonValue> for f64 {
    type Error = MyError;

    fn try_from(value: JsonValue) -> Result<Self, Self::Error> {
        match value {
            JsonValue::Number(f) => Ok(f),
            _ => Err(MyError::ParseError),
        }
    }
}
```

### FromStr

First of all, let's look at the `FromStr` trait:

```rust
trait FromStr {
    type Err;
    fn from_str(s: &str) -> Result<Self, Self::Err>;
}
```

That is to say, any types who implemented this trait can be constructed from a `&str`. A complex example I've provided is in [this article](https://jacobbishopxy.github.io/posts/a-taste-of-nom/), in which I used `nom`, a parser combinator, to parse complex string structure.

### AsRef & AsMut

Take a look at their signature:

```rust
trait AsRef<T: ?Sized> {
    fn as_ref(&self) -> &T;
}

trait AsMut<T: ?Sized> {
    fn as_mut(&mut self) -> &mut T;
}
```

Both `AsRef` and `AsMut` are similar to `From` or `Into`, instead they do not take ownership but providing immutable reference and mutable reference respectively. `AsRef` is commonly used in many places, for example, in `std::fs::File`:

> ```rust
> pub fn open<P: AsRef<Path>>(path: P) -> io::Result<File> {
>     OpenOptions::new().read(true).open(path.as_ref())
> }
> ```

We can use `File::Open` to open a file from different sources, such as URL, file path, etc.

`AsMut`, however, is seldom used in my experience, so for illustration, I made an example of `AsMut`. In the example below, I wrote two functions `zoom_1` and `zoom_2`, and you will see by using `AsMut` as a function's generic parameter, `zoom_1` is capable of tackle both `Box<T>` and `T` arguments.

```rust
// describes all the behavior of a type:
// - area: calculates the area of a shape
// - zoom: used for mutating the type's fields
trait Shape {
    fn area(&self) -> f64;

    fn zoom(&mut self, factor: f64);
}

// concrete type #1
struct Rectangle {
    width: f64,
    height: f64,
}

impl Shape for Rectangle {
    fn area(&self) -> f64 {
        self.width * self.height
    }

    fn zoom(&mut self, factor: f64) {
        self.width *= factor;
        self.height *= factor;
    }
}

// impl AsMut<dyn Shape>
// lifetime parameter 'a is required for `dyn Shape`
impl<'a> AsMut<dyn Shape + 'a> for Rectangle {
    fn as_mut(&mut self) -> &mut (dyn Shape + 'a) {
        self
    }
}

// concrete type #2
struct Triangle {
    base: f64,
    height: f64,
}

impl Shape for Triangle {
    fn area(&self) -> f64 {
        self.base * self.height / 2.0
    }

    fn zoom(&mut self, factor: f64) {
        self.base *= factor;
        self.height *= factor;
    }
}

impl<'a> AsMut<dyn Shape + 'a> for Triangle {
    fn as_mut(&mut self) -> &mut (dyn Shape + 'a) {
        self
    }
}

struct Circle {
    radius: f64,
}

impl Shape for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * self.radius * self.radius
    }

    fn zoom(&mut self, factor: f64) {
        self.radius *= factor;
    }
}

impl<'a> AsMut<dyn Shape + 'a> for Circle {
    fn as_mut(&mut self) -> &mut (dyn Shape + 'a) {
        self
    }
}

// zoom_1 is more flexible than zoom_2
#[allow(dead_code)]
fn zoom_1<T: AsMut<dyn Shape>>(shape: &mut T, factor: f64) {
    shape.as_mut().zoom(factor);
}

// zoom_2 only accepts `Box<dyn Shape>`
#[allow(dead_code)]
fn zoom_2(shape: &mut Box<dyn Shape>, factor: f64) {
    shape.zoom(factor);
}

#[test]
fn test_zoom_1() {
    let mut rectangle = Rectangle {
        width: 10.0,
        height: 20.0,
    };

    zoom_1(&mut rectangle, 2.0);
}

#[test]
fn test_zoom_2() {
    let rectangle = Rectangle {
        width: 10.0,
        height: 20.0,
    };

    let mut rectangle = Box::new(rectangle) as Box<dyn Shape>;

    zoom_2(&mut rectangle, 2.0);
}

#[test]
fn test_zoom_vec_shape() {
    let mut vec: Vec<Box<dyn Shape>> = vec![
        Box::new(Rectangle {
            width: 10.0,
            height: 20.0,
        }),
        Box::new(Triangle {
            base: 10.0,
            height: 20.0,
        }),
        Box::new(Circle { radius: 10.0 }),
    ];

    // here we can use both zoom_1 and zoom_2
    vec.iter_mut().for_each(|shape| {
        // `shape` satisfies both `AsMut<dyn Shape>` and `Box<dyn Shape>`
        zoom_1(shape, 2.0);
        zoom_2(shape, 2.0);
    });

    for item in vec.iter() {
        let area = item.area();

        println!("{:?}", area);
    }
}

#[test]
fn test_zoom_vec_rectangle() {
    let mut vec = vec![
        Rectangle {
            width: 10.0,
            height: 20.0,
        },
        Rectangle {
            width: 12.0,
            height: 18.0,
        },
        Rectangle {
            width: 14.0,
            height: 16.0,
        },
    ];

    // zoom_2 is no longer applicable
    vec.iter_mut().for_each(|shape| {
        // `shape` satisfies only `AsMut<dyn Shape>`
        zoom_1(shape, 2.0);
        // no more allowed here
        // zoom_2(shape, 2.0);
    });

    for item in vec.iter() {
        let area = item.area();

        println!("{:?}", area);
    }
}

```

### Borrow & BorrowMut

```rust
trait Borrow<Borrowed>
where
    Borrowed: ?Sized,
{
    fn borrow(&self) -> &Borrowed;
}

trait BorrowMut<Borrowed>: Borrow<Borrowed>
where
    Borrowed: ?Sized,
{
    fn borrow_mut(&mut self) -> &mut Borrowed;
}
```

> These traits were invented to solve the very specific problem of looking up `String` keys in `HashSet`s, `HashMap`s, `BTreeSet`s, and `BTreeMap`s using `&str` values.
>
> We can view `Borrow<T>` and `BorrowMut<T>` as stricter versions of `AsRef<T>` and `AsMut<T>`, where the returned reference `&T` has equivalent `Eq`, `Hash`, and `Ord` impls to `Self`.

According to the author, these traits are very rare that we would ever need to implement them, so let's skip their example for now.

### ToOwned

```rust
trait ToOwned {
    type Owned: Borrow<Self>;
    fn to_owned(&self) -> Self::Owned;

    // provided default impls
    fn clone_into(&self, target: &mut Self::Owned);
}
```

> For similar reasons as Borrow and BorrowMut, it's good to be aware of this trait and understand why it exists but it's very rare we'll ever need to impl it for any of our types.

## Iteration Traits

### Iterator

Let's use `TreeNode` as an example, we can implement multiple iteration methods. First, define `TreeNode` struct:

```rust
#[derive(Debug, PartialEq, Eq, Clone)]
pub struct TreeNode {
    pub val: i32,
    pub left: Option<Rc<RefCell<TreeNode>>>,
    pub right: Option<Rc<RefCell<TreeNode>>>,
}

impl TreeNode {
    pub fn new(val: i32) -> Self {
        TreeNode {
            val,
            left: None,
            right: None,
        }
    }
}
```

Next, we need two struct, one for implementing `Iterator` trait and another for `IntoIterator`:

```rust
use std::cell::RefCell;
use std::collections::VecDeque;
use std::rc::Rc;

// impl `Iterator`
pub struct IntoIteratorLR {
    que: VecDeque<Rc<RefCell<TreeNode>>>,
}

impl Iterator for IntoIteratorLR {
    type Item = i32;

    fn next(&mut self) -> Option<Self::Item> {
        if self.que.is_empty() {
            None
        } else {
            let node = self.que.pop_front().unwrap();
            if let Some(n) = node.borrow().left.clone() {
                self.que.push_back(n);
            }
            if let Some(n) = node.borrow().right.clone() {
                self.que.push_back(n);
            }

            return Some(node.borrow().val);
        }
    }
}

// impl `IntoIterator`
pub struct TreeNodeByLeftRightLevelOrder(TreeNode);

impl IntoIterator for TreeNodeByLeftRightLevelOrder {
    type Item = i32;
    type IntoIter = IntoIteratorLR;

    fn into_iter(self) -> Self::IntoIter {
        let mut que = VecDeque::new();
        que.push_back(Rc::new(RefCell::new(self.0)));

        IntoIteratorLR { que }
    }
}
```

Then we can have a new method `iter_left_right_level_order`:

```rust
impl TreeNode {
    pub fn iter_left_right_level_order(self) -> IntoIteratorLR {
        TreeNodeByLeftRightLevelOrder(self).into_iter()
    }
}
```

Finally, our unit test:

```rust
macro_rules! new_node {
    ($num:expr) => {
        Some(Rc::new(RefCell::new(TreeNode::new($num))))
    };
}


#[test]
fn level_order_success() {
    let root = TreeNode {
        val: 1,
        left: Some(Rc::new(RefCell::new(TreeNode {
            val: 2,
            left: new_node!(3),
            right: new_node!(4),
        }))),
        right: Some(Rc::new(RefCell::new(TreeNode {
            val: 5,
            left: new_node!(6),
            right: new_node!(7),
        }))),
    };

    let v = root.iter_left_right_level_order().collect::<Vec<_>>();

    assert_eq!(vec![1, 2, 5, 3, 4, 6, 7], v);
}
```

Check [this](https://github.com/Jacobbishopxy/jotting/blob/master/std-traits/src/tree_node_traverse.rs) for more detail (including different ways of iteration).

### IntoIterator

TODO: example

### FromIterator

TODO: example

## I/O Traits

### Read & Write

TODO: example

## Summary

to be continued...
