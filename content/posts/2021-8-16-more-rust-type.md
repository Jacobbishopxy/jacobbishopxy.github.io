+++
title = "More Rust Type"
description = "Study note"
date = 2021-08-16

[taxonomies]
categories = ["Read"]
tags = ["Rust"]

[extra]
toc = true
+++

Study note from [Untapped potential in Rust's type system](https://www.jakobmeier.ch/blogging/Untapped-Rust.html).

## Warm up

> Types are a very abstract concept.

In most of the languages, types are things used to describe variables' form, and some languages like Haskell, types are elements which have been endowed by black magic. As the author mentioned, the whole Haskell program seems like written in the type system itself, and what I've learned from Scala functional programing has the same idea. Be short, it is basically implementing some functional trait for a type, for example a `F[_]` who implemented `def map` can be treaded as a Functor (actually more complected than this).

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
>     let t1 = TypeId::of::<u32>();
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

Well :thinking:, it only works for `'static` right now, and I thought it could not help us for now. But the author amazed me by using `Box<dyn>` syntax to create trait objects, so that a type can be compared by `TypeId` (full code):

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

Here the `Any` trait provides a `type_id()` method, which is the key of identification. Similarly, the author provides another function that can be used for removing the first rectangle from a vector:

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

The difference between these two functions `count_rectangles` and `remove_first_rectangle` is there input argument. Not only the type's mutability but also the `dyn` trait object. For the second function, we can't use `dyn Shape` to replace `dyn Any`, because `Shape` trait doesn't have `downcast` method.

Here is the definition of `downcast`:

````rs
impl<A: Allocator> Box<dyn Any, A> {
    #[inline]
    #[stable(feature = "rust1", since = "1.0.0")]
    /// Attempt to downcast the box to a concrete type.
    ///
    /// # Examples
    ///
    /// ```
    /// use std::any::Any;
    ///
    /// fn print_if_string(value: Box<dyn Any>) {
    ///     if let Ok(string) = value.downcast::<String>() {
    ///         println!("String ({}): {}", string.len(), string);
    ///     }
    /// }
    ///
    /// let my_string = "Hello World".to_string();
    /// print_if_string(Box::new(my_string));
    /// print_if_string(Box::new(0i8));
    /// ```
    pub fn downcast<T: Any>(self) -> Result<Box<T, A>, Self> {
        if self.is::<T>() {
            unsafe {
                let (raw, alloc): (*mut dyn Any, _) = Box::into_raw_with_allocator(self);
                Ok(Box::from_raw_in(raw as *mut T, alloc))
            }
        } else {
            Err(self)
        }
    }
}
````

That is to say, with `downcast`, we can 'transform' an `Any` type to some specific type.

## Heterogenous Collection

However, directly passing `Box<dyn Any>` around is not always a good idea.

> To avoid manual downcasting on the caller side, it can be hidden behind a generic function.

And here is an example, in where I made some changes, from the author's original code:

<details>
<summary>Click to expand</summary>

```rs
use std::{
    any::{Any, TypeId},
    collections::HashMap,
};

fn main() {
    // Before
    let mut collection = HeteroCollection::default();
    collection.set("name", "Jakob");
    collection.set("language", "Rust");
    collection.set("dominant hand", DominantHand::Right);

    let _name = collection.get::<&'static str>("name");
    let _language = collection.get::<&'static str>("language");
    let _dominant_hand = collection.get::<DominantHand>("dominant hand");

    println!("{:#?}", collection);

    // After
    let mut collection = SingletonCollection::default();
    collection.set(Name("Jakob"));
    collection.set(Language("Rust"));
    collection.set(DominantHand::Right);

    let _name = collection.get::<Name>().0;
    let _language = collection.get::<Language>().0;
    let _dominant_hand = collection.get::<DominantHand>();

    println!("{:#?}", collection);
}

// Use string as key
#[derive(Default, Debug)]
struct HeteroCollection {
    data: HashMap<&'static str, Box<dyn Any>>,
}

impl HeteroCollection {
    pub fn get<T: 'static>(&self, key: &'static str) -> Option<&T> {
        let unknown_output: &Box<dyn Any> = self.data.get(key)?;
        unknown_output.downcast_ref()
    }

    pub fn set<T: 'static>(&mut self, key: &'static str, value: T) {
        self.data.insert(key, Box::new(value));
    }
}

// Use `TypeId` as key
#[derive(Default, Debug)]
struct SingletonCollection {
    data: HashMap<TypeId, Box<dyn Any>>,
}

impl SingletonCollection {
    pub fn get<T: Any>(&self) -> &T {
        self.data[&TypeId::of::<T>()]
            .downcast_ref()
            .as_ref()
            .unwrap()
    }

    pub fn set<T: Any>(&mut self, value: T) {
        self.data.insert(TypeId::of::<T>(), Box::new(value));
    }
}

// For completeness: Type Definitions
struct Name(&'static str);
struct Language(&'static str);
pub enum DominantHand {
    Left,
    Right,
    Both,
    Neither,
    Unknown,
    Other,
}
```

</details>
</br>

The well printed result:

```t
HeteroCollection {
    data: {
        "name": Any { .. },
        "dominant hand": Any { .. },
        "language": Any { .. },
    },
}
SingletonCollection {
    data: {
        TypeId {
            t: 16692126412618073318,
        }: Any { .. },
        TypeId {
            t: 13748357137106968353,
        }: Any { .. },
        TypeId {
            t: 13740187421581971802,
        }: Any { .. },
    },
}
```

Clearly, the difference between these two structs is hashmap's key type: one is string and the other is `TypeId`. However, they work quit differently:

> the type-key must be known at compile-time, whereas the string could be determined at runtime.

Amazing, isn't it? Not until I read an article about [taxonomy](https://en.wikipedia.org/wiki/Taxonomy), I realize this is actually solving a classic categorization problem.

In rust, there are three ways to achieve a categorizing design. The first one is to use Type & Trait, and this is done before compile, which means first of all we describe concrete types, and use trait to conclude them. The second one is `Type<T: Trait>`, and the last one is using Enum.

Let's look at the first method, and I use World of Warcrafts' role as an example:

```rs
fn main() {
    attack_command(Rogue);
}

struct Rogue;

struct Warrior;

pub trait Melee {
    fn base_attack(&self) -> usize;
}

impl Melee for Rogue {
    fn base_attack(&self) -> usize {
        5
    }
}

impl Melee for Warrior {
    fn base_attack(&self) -> usize {
        10
    }
}

fn attack_command<T: Melee>(role: T) {
    println!("hit: {:?} pts", role.base_attack())
}
```

The next demand is to implement `upcast` and `downcast`, which means a concrete type turns to a trait object and a trait object turns to a concrete type, respectively. A normal way to handle this problem is add `downcast` support to a trait, for example:

```rs
use std::any::Any;

fn main() {
    let foo = Warrior.as_any_ref();
    let bar = foo.downcast_ref::<Warrior>();
    println!("{:?}", bar);
}

#[derive(Debug)]
struct Warrior;

pub trait Melee {
    fn base_attack(&self) -> usize;

    fn as_any_ref(&self) -> &dyn Any;

    fn as_any_mut(&mut self) -> &mut dyn Any;
}

impl Melee for Warrior {
    fn base_attack(&self) -> usize {
        10
    }

    fn as_any_ref(&self) -> &dyn Any {
        self
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}
```

Ta-da! Simple and strait forward! And what about the second method? What exactly is a `Type<T: Trait>`?

```rs
fn main() {
    let warrior = Warrior {
        role: Melee,
        attack: Box::new(Attack1),
    };

    println!("{:?}", warrior.attack.base_attack());

    let rogue = Rogue {
        role: Melee,
        attack: Attack2,
    };

    println!("{:?}", rogue.attack.base_attack());
}

// Common parts
pub struct Melee;

pub trait Attack {
    fn base_attack(&self) -> usize;
}

// Case #1:
pub struct Warrior {
    pub role: Melee, // inherit from parent
    pub attack: Box<dyn Attack>,
}

// Case #2:
pub struct Rogue<T: Attack> {
    pub role: Melee, // inherit from parent
    pub attack: T,
}

// implementation of warrior's attack
struct Attack1;

impl Attack for Attack1 {
    fn base_attack(&self) -> usize {
        10
    }
}

// implementation of rogue's attack
struct Attack2;

impl Attack for Attack2 {
    fn base_attack(&self) -> usize {
        5
    }
}
```

No doubt, with `Box` case #1 works for runtime, and case #2 only suitable before compile. For the third method using enum is quite the same as case #2, which means they are all `Sized` so that categorizing only works before compile. Anyway, let's move on and see what dynamic type can do for us.

## Type-Oriented

Then we come to the second part, use these techs in the real world.

> What I’m going to show you could be described as object-oriented message passing with the twist that types are used as object addresses and also for dynamic dispatch.

The purpose of using singleton objects with dynamic dispatch is to solve borrowing issue when a variable is sharable, especially sharable among threads. The normal way to handle this issue is to use `Rc<RefCell>` in sync env or `Arc<RefCell>` in async env.

Let's take a look the full code the author provides us. A little bit too long, so I collapsed it here:

<details>
<summary>Click to expand</summary>

```rs
struct MyObject {
   counter: u32,
}

struct MethodA;

struct MethodBWithArguments {
   text: String,
}

impl MyObject {
   fn method_a(&mut self, _arg: MethodA) {
       self.counter += 1;
       println!(
           "Object invoked a method {} times. This time without an argument.",
           self.counter
       );
   }

   fn method_b(&mut self, arg: MethodBWithArguments) {
       self.counter += 1;
       println!(
           "Object invoked a method {} times. This time with argument: {}",
           self.counter, arg.text
       );
   }
}

fn main() {
   /* registration */
   let obj = MyObject { counter: 0 };
   my_library::register_object(obj);
   my_library::register_method(MyObject::method_a);
   my_library::register_method(MyObject::method_b);

   /* invocations */
   my_library::invoke::<MyObject, _>(MethodA);
   my_library::invoke::<MyObject, _>(MethodBWithArguments {
       text: "Hello World!".to_owned(),
   });

   /* Output */
   // ...
}

mod my_library {
   use std::{
       any::{Any, TypeId},
       collections::HashMap,
   };

   // Assume `register_object` and `register_method` are called on it
   pub struct Nut {
       // states
       objects: HashMap<TypeId, Box<dyn Any>>,
       // methods
       methods: HashMap<(TypeId, TypeId), Box<dyn FnMut(&mut Box<dyn Any>, Box<dyn Any>)>>,
   }

   impl Nut {
       // use for storing states
       pub fn register_object<OBJECT>(&mut self, obj: OBJECT)
       where
           OBJECT: Any,
       {
           let key = TypeId::of::<OBJECT>();
           let boxed_obj = Box::new(obj);
           self.objects.insert(key, boxed_obj);
       }

       // 1. Look up the object.
       // 2. Look up the method.
       // 3. Call the method with the object and the invocation argument.
       pub fn invoke<OBJECT, ARGUMENT>(&mut self, arg: ARGUMENT)
       where
           OBJECT: Any,
           ARGUMENT: Any,
       {
           let object_key = TypeId::of::<OBJECT>();
           let method_key = (TypeId::of::<OBJECT>(), TypeId::of::<ARGUMENT>());
           if let Some(obj) = self.objects.get_mut(&object_key) {
               if let Some(method) = self.methods.get_mut(&method_key) {
                   method(obj, Box::new(arg));
               }
           }
       }

       // use for storing objects' methods
       pub fn register_method<OBJECT, ARGUMENT, FUNCTION>(&mut self, mut method: FUNCTION)
       where
           FUNCTION: FnMut(&mut OBJECT, ARGUMENT) + 'static,
           ARGUMENT: Any,
           OBJECT: Any,
       {
           let key = (TypeId::of::<OBJECT>(), TypeId::of::<ARGUMENT>());
           let wrapped_method =
               Box::new(move |any_obj: &mut Box<dyn Any>, any_args: Box<dyn Any>| {
                   let obj: &mut OBJECT = any_obj.downcast_mut().expect("Type conversion failed");
                   let args: ARGUMENT = *any_args.downcast().expect("Type conversion failed");
                   method(obj, args)
               });
           self.methods.insert(key, wrapped_method);
       }
   }

   // The real nuts code has absolutely no unsafe code.
   // But just for readability, global data is stored as mutable static in this example.
   static mut NUT: Option<Nut> = None;
   fn get_nut() -> &'static mut Nut {
       unsafe {
           NUT.get_or_insert_with(|| Nut {
               objects: HashMap::new(),
               methods: HashMap::new(),
           })
       }
   }

   pub fn register_object(obj: impl Any) {
       get_nut().register_object(obj);
   }
   pub fn register_method<OBJECT, ARGUMENT, FUNCTION>(method: FUNCTION)
   where
       FUNCTION: FnMut(&mut OBJECT, ARGUMENT) + 'static,
       ARGUMENT: Any,
       OBJECT: Any,
   {
       get_nut().register_method(method);
   }
   pub fn invoke<OBJECT, ARGUMENT>(method_call: ARGUMENT)
   where
       OBJECT: Any,
       ARGUMENT: Any,
   {
       get_nut().invoke::<OBJECT, ARGUMENT>(method_call);
   }
}
```

</details>
</br>

One thing that we should know before moving on is to be clear about a `'static` bound. According to [this post](https://stackoverflow.com/a/48018183/8163324):

> 1. If explicitly given, use that lifetime.
>
> 1. Otherwise, it is inferred from the inner trait. For example, `Box<Any>` is `Box<Any + 'static>` because `Any: 'static`.
>
> 1. If the trait doesn't have an appropriate lifetime, it is inferred from the outer type. For example, `&'a >Fn()` is `&'a (Fn() + 'a)`.
>
> 1. If that even failed, it falls back to `'static` (for a function signature) or an anonymous lifetime (for a function body).

If we don't have the `'static` bound right after the `FnMut`, we'll see a compile error as following:

```terminal
   Compiling more-rust-type v0.1.0 (***)
error[E0310]: the parameter type `FUNCTION` may not live long enough
   --> more-rust-type/src/bin/type_oriented.rs:102:38
    |
89  |         pub fn register_method<OBJECT, ARGUMENT, FUNCTION>(&mut self, mut method: FUNCTION)
    |                                                  -------- help: consider adding an explicit lifetime bound...: `FUNCTION: 'static`
...
102 |             self.methods.insert(key, wrapped_method);
    |                                      ^^^^^^^^^^^^^^ ...so that the type `[closure@more-rust-type/src/bin/type_oriented.rs:97:26: 101:18]` will meet its required lifetime bounds

For more information about this error, try `rustc --explain E0310`.
error: could not compile `more-rust-type` due to previous error
The terminal process "cargo 'run', '--package', 'more-rust-type', '--bin', 'type_oriented'" failed to launch (exit code: 101).
```

Which is saying as a trait, `FUNCTION` should live longer than the whole `Nut` struct. It's actually a function who will be registered into a `Nut` instance, and this function is defined before compilation, so giving it a `'static` lifetime bound is therefore very appropriate.

We can learn several things from the code.

- First, `Nut` is a struct holds two `HashMap`, one for object instances, whose key is a unique `TypeId`, and if you register a same type of object twice, the first one will be overrode (which mentioned by the author: "The global storage keeps only one object of each type."); another field is used for storing object's methods, so that we can invoke these methods by specifying object's type and their argument in the future. Moreover, each time invoking a method, object's type should be provided as type param to the `invoke` function. Otherwise, library would not know which object's method user is calling. This is quite like calling iterator `.collect()` method from the standard library (user should explicitly announce the type they wish to convert).

- Second, inside `methods` field, `Box<dyn FnMut(&mut Box<dyn Any>, Box<dyn Any>)>` is used as method's signature. `FnMut` is more general than `Fn`, because it allows arguments' mutation. Furthermore, `&mut Box<dyn Any>` is used as input argument type, and `Box<dyn Any>` as output. Notice, since input argument type is `&mut Box<dyn Any>`, all the registered methods should be written as `fn method_x(&mut self, arg: ...)`, and signature like `fn method_y(&self, arg: ...)` is not allowed to registration.

- Last, the `invoke` function: using `OBJECT` type argument to find out the object instance, and finding out its registered method, then finally calling the method with object instance and argument instance.

Although the code solved general heterogenous storage and method calling at the time, it is still cumbersome and rough for a library crate. But no worry! Please learn more about the 'real' library [Nuts](https://github.com/jakmeier/nuts) written by the author.

## Generalizing TypeId

In the previous two sections, the author has shown us how type IDs are useful within a single binary, and now we are going to seek things beyond the binary boundary, which means the type is totally not known at compile time.

Wait a minute, so I know the `TypeId` is actually a private `u64`, and it's given by compiler, but what effects its generation? I made a test according to the article, which says:

> - Renaming the struct
> - Renaming fields
> - Moving the definition to another module
> - Syntax changes (e.g. `MyType{}` to `MyType`)

And these changes will not change the `TypeId`:

> - Changing the type of a field
> - Adding methods in an `impl` block or through a `#[derice(...)]`

<details>
<summary>Click to expand the test code</summary>

1. Renaming the struct

   ```rs
   fn main() {
       struct S1;

       println!("{:?}", TypeId::of::<S1>());
       // TypeId { t: 15705126685411935490 }
   }
   ```

   ```rs
   fn main() {
       struct S2;

       println!("{:?}", TypeId::of::<S3>());
       // TypeId { t: 8903374546367185742 }
   }
   ```

1. Renaming fields

   ```rs
   fn main() {
       struct S {
           _v1: usize,
       }

       println!("{:?}", TypeId::of::<S>());
       // TypeId { t: 5679131806921150377 }
   }
   ```

   ```rs
   fn main() {
       struct S {
           _v2: usize,
       }

       println!("{:?}", TypeId::of::<S>());
       // TypeId { t: 18316776490602311238 }
   }
   ```

1. Moving the definition to another module

   ```rs
   mod M1 {
   pub struct S;
   }

   fn main() {
       use M1::S;

       println!("{:?}", TypeId::of::<S>());
       // TypeId { t: 89908796858884930 }
   }
   ```

   ```rs
   mod M2 {
   pub struct S;
   }

   fn main() {
       use M1::S;

       println!("{:?}", TypeId::of::<S>());
       // TypeId { t: 17526344372340483910 }
   }
   ```

1. Syntax changes

   ```rs
   fn main() {
       struct S;

       println!("{:?}", TypeId::of::<S>());
       // TypeId { t: 17803636430605880271 }
   }
   ```

   ```rs
   fn main() {
       struct S {};

       println!("{:?}", TypeId::of::<S>());
       // TypeId { t: 6576500625851552798 }
   }
   ```

1. **(NOT changing TypeId)** Changing the type of a field:

   ```rs
   struct S1 {
       v: i32,
   }

   fn main() {
       println!("{:?}", TypeId::of::<S1>());
       // TypeId { t: 3771603622093412445 }
   }
   ```

   ```rs
   struct S1 {
       v: String,
   }

   fn main() {
       println!("{:?}", TypeId::of::<S1>());
       // TypeId { t: 3771603622093412445 }
   }
   ```

1. **(NOT changing TypeId)** Changing the type of a field:

   ```rs
   struct S1;

   fn main() {
       println!("{:?}", TypeId::of::<S1>());
       // TypeId { t: 6307292858813541705 }
   }
   ```

   ```rs
   struct S1;

   impl S1 {
       fn f() {
           println!("f()")
       }
   }

   fn main() {
       println!("{:?}", TypeId::of::<S1>());
       // TypeId { t: 6307292858813541705 }
   }
   ```

</details>
</br>

According to the Rust official documentation:

> While TypeId implements Hash, PartialOrd, and Ord, it is worth noting
> that the hashes and ordering will vary between Rust releases.
> Beware of relying on them inside of your code!

Apparently, `TypeId` isn't designed to be used sharing among many binaries. As the author's dream is to accomplish a networked dynamic publish-subscribe system, then implementing an own `TypeId` is therefore very necessary.

So let's take a look on how to produce an Universal type Id.

First create a trait called `UniversalType`, and any type that implement this trait will get a `UniversalTypeId` (same as `TypeId` for any type).

Take a glance of [the implementation](https://github.com/jakmeier/universal-type-id/blob/06fcfb0e122fd32e4383750a17a76b50384c2e3b/uti/src/lib.rs#L10):

> ```rs
> #[derive(Copy, Clone, Hash, PartialEq, Eq, PartialOrd, Ord, Debug)]
> #[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
> pub struct UniversalTypeId {
>     bytes: [u8; MAX_UTI_BYTES],
> }
> pub trait UniversalType: Any {
>     /// Raw bytes which are the result of the universal type hash
>     const UNIVERSAL_TYPE_ID_BYTES: [u8; MAX_UTI_BYTES];
>
>     /// A type id as  a hash over the type name and fields
>     fn universal_type_id(&self) -> UniversalTypeId {
>         UniversalTypeId::of::<Self>()
>     }
> }
> ```

After this, a procedure macro is written out for deriving. For more details please visit [the repo](https://github.com/jakmeier/universal-type-id).

And the usage of this crate is pretty simple:

> ```rs
> #[derive(UniversalType)]
> struct Person {
>    name: String,
>    year: i16,
> }
>
> fn main() {
>    let uid = UniversalTypeId::of::<Person>();
>    println!("Numerical value of universal type ID: {}", uid.as_u128());
> }
> ```

Apparently, comparing to the previous work, using this `UniversalTypeId` to replace `TypeId` from standard library will give us more accuracy on the expression, such as `HashMap<UniversalTypeId, Box<dyn Any>>` who has the same functionality as `HashMap<TypeId, Box<dyn Any>>`, but is capable to distinguish types deeper. The rest of the work is all about serialize and deserialize since the memory layout of Rust is not stable, and using serialize/deserialize can ensure memory safe.

## My Thoughts

After all I have read and done, I found that myself is getting closer to Rust type system. Previously, what I've learned from THE BOOK gives me a general picture of Rust type system. It introduces the type in static env, which only works for compile time, for example generic type turns to actual type after compiling, and trait object, a way to mimic same type in runtime, is unsized at compile time but with sized self annotation, so that compiler can allocate stack memory for it, and leave the rest of work on heap allocation by using a pointer. And now I've learned that Rust standard library provides us a tool to help us on dynamic type. In short, it allows us to downcast a `Any` type to a pre-defined trait object at runtime. Using such kind of technique can allow us to implement more creative thoughts, such as the code author shown us. I have to say, this is still a big class for me that deserves me to study type system all over again, systematically. Hopefully, I can write more articles about type system in a general way after some researches. Alright, being through a long day, I think I should probably end this, and until next time, happy coding :wave:.
