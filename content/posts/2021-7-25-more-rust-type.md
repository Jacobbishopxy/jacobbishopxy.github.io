+++
title = "More Rust Type"
description = "Study note"
date = 2021-07-25

[taxonomies]
categories = ["Read"]
tags = ["Rust"]

+++

Study note from [Untapped potential in Rust's type system](https://www.jakobmeier.ch/blogging/Untapped-Rust.html).

> Types are a very abstract concept.

In most of the languages, types are things used to describe variables' form, and some languages like Haskell, types are elements which have been endowed by black magic. As the author says, the whole Haskell program seems like written in the type system itself, and what I've learned from Scala functional programing has the same idea. Be short, it is basically implementing some functional trait for a type, for example a `F[_]` who implemented `def map` can be treaded as a Functor (actually more complected than this).

Type has more meanings in Rust. With ownership system, we have immutable `&` and mutable `&mut` reference type, and we also have lifetime type such as `'static`. But these are types working in compile time, which is not enough for runtime.

> However, Rust offers ways to manually store type information which can be used also at runtime.

Which is saying a fat pointer, who actually points to a vtable, and is called a trait object in Rust. Sadly, a trait object has its' limitation, because as [THE BOOK](https://doc.rust-lang.org/book) taught, it should obey object safe rules. Be brief, defining a trait for trait object needs to specify its methods' input and output size (coming with `Sized` trait tag).

Alright, here comes the part that is not taught in THE BOOK. The author introduces a crate from standard library, and it goes like:

> ```rs
> use core::any::{Any, TypeId};
>
> fn main() {
>     let one_hundred = 100u32;
>     // Get the type ID using a value of that type.
>     let t0 = one_hundred.type_id();
>     // Get the type ID directly.
>     let t1 = TypeId::od::<u32>();
>
>     assert_eq!(t0, t1);
> }
> ```

A little bit curiosity comes from me when I print these variables:

```t
t0: TypeId { t: 12849923012446332737 }
t1: TypeId { t: 12849923012446332737 }
```

What exactly a `TypeId` is? Then I look into its definition:

```rs
/// A `TypeId` represents a globally unique identifier for a type.
///
/// Each `TypeId` is an opaque object which does not allow inspection of what's
/// inside but does allow basic operations such as cloning, comparison,
/// printing, and showing.
///
/// A `TypeId` is currently only available for types which ascribe to `'static`,
/// but this limitation may be removed in the future.
///
/// While `TypeId` implements `Hash`, `PartialOrd`, and `Ord`, it is worth
/// noting that the hashes and ordering will vary between Rust releases. Beware
/// of relying on them inside of your code!
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Hash)]
#[stable(feature = "rust1", since = "1.0.0")]
pub struct TypeId {
    t: u64,
}
```

Well, it only works for `'static` right now, and I don't think it could help us for now. But the author amazed me by using `Box<dyn>` syntax which creates trait objects, so that type can be compared by `TypeId` (full code):

> ```rs
> use core::any::{Any, TypeId};
> use std::ops::Deref;
>
> struct Rectangle;
> struct Triangle;
>
> trait Shape: Any {}
>
> impl Shape for Rectangle {}
> impl Shape for Triangle {}
>
> fn main() {
>    let shapes: Vec<Box<dyn Shape>> =
>        vec![Box::new(Rectangle), Box::new(Triangle), Box::new(Rectangle)];
>    let n = count_rectangles(&shapes);
>    assert_eq!(2, n);
> }
>
> fn count_rectangles(shapes: &[Box<dyn Shape>]) -> usize {
>    let mut n = 0;
>    for shape in shapes {
>        // Need to derefernce once or we will get the type of the Box!
>        let type_of_shape = shape.deref().type_id();
>        if type_of_shape == TypeId::of::<Rectangle>() {
>            n += 1;
>        } else {
>            println!("{:?} is not a Rectangle!", type_of_shape);
>        }
>    }
>    n
> }
> ```

Here the `Any` trait provides a `type_id()` method, which is the key. Another function used to remove first rectangle from a vector:

> ```rs
> use core::any::{Any, TypeId};
> use std::ops::Deref;
>
> struct Rectangle;
> struct Triangle;
>
> trait Shape: Any {}
>
> impl Shape for Rectangle {}
> impl Shape for Triangle {}
>
> fn main() {
>    let mut shapes: Vec<Box<dyn Any>> =
>        vec![Box::new(Rectangle), Box::new(Triangle), Box::new(Rectangle)];
>    remove_first_rectangle(&mut shapes).expect("No rectangle found to be removed");
> }
>
> fn remove_first_rectangle(shapes: &mut Vec<Box<dyn Any>>) -> Option<Box<Rectangle>> {
>    let idx = shapes
>        .iter()
>        .position(|shape| shape.deref().type_id() == TypeId::of::<Rectangle>())?;
>    let rectangle_as_unknown_shape = shapes.remove(idx);
>    rectangle_as_unknown_shape.downcast().ok()
> }
> ```

to be continue...
