+++
title = "Impl Index for polars' Series"
description = "A little"
date = 2022-08-01

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

+++

## Intro

Today I would like to talk about a small problem I met in my project, and the inspired thoughts through the whole working process. While trying to select data from Series or DataFrame, the intuitive thought is how to make Rust DataFrame's selection similar to Python's DataFrame? For example, we have `iat`, `at`, `iloc` and `loc` methods in pandas' DataFrame, which represents _accessing integer location scalar_, _accessing a single value for a row/column label pair_, _accessing a group of rows and columns by integer position(s)_, and _accessing a group of rows and columns by label(s)_ respectfully.

The first idea came to me is that implementing `Index` trait for polars series can approach the same effect as pandas DataFrame does. As a syntactic sugar of `foo.index(index)`, `Index` provide us a simple way to get an indexed of value from a variable.

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

Before moving forward, we need a small review of `polars` crate. There are mainly two methods to get a value from a series: call `.get(index)` method directly on a Series, and from its signature we know the return type is `AnyValue`, whose variants represents different types of data; the second method is unpacking series to `ChunkedArray<T>` by calling `.bool()`, `.i32()` and etc., and by calling `.get(index)` get `T` value. The former method has a runtime cast (`T` -> `AnyValue`), and the latter method has better performance. According to [polars::chunked_array::ChunkedArray](https://docs.rs/polars/latest/polars/chunked_array/struct.ChunkedArray.html):

> Every Series contains a `ChunkedArray<T>`. Unlike Series, ChunkedArray’s are typed. This allows us to apply closures to the data and collect the results to a `ChunkedArray` of the same type `T`.
>
> ...
>
> Conversion from a `Series` to a `ChunkedArray` is effortless.

One thing is very important but not really a relevant concept to our topic is `ChunkedArray`'s memory layout:

> `ChunkedArray`’s use [Apache Arrow](https://github.com/apache/arrow) as backend for the memory layout. Arrows memory is immutable which makes it possible to make multiple zero copy (sub)-views from a single array.

It gives us a better conceptual view of a `Series`. Now, back to our design. From the two `.get(index)` methods introduced above, we found that neither getting value from a Series directly nor getting value from a ChunkedArray would return a referenced value. In other words, we have to cache this value in somewhere first, which grants this value a longer lifetime of existence, or else it will be dropped after the `index` function's scope. Therefore, we need a struct who has at least two fields in which the data refers to the original series and the cached state, who holds the temporary value returned by the `get` method, lives as long as the struct itself.

```rust
struct MySeriesIndexing<'a> {
    data: &'a Series,
    cache: Box<dyn MyValueTrait>,
}

#[allow(dead_code)]
impl<'a> MySeriesIndexing<'a> {
    fn new(series: &'a Series) -> Self {
        Self {
            data: series,
            cache: Box::new(Null),
        }
    }
}
```

Next is the vital part of our design: implementing `Index` trait for our `MySeriesIndexing`. First and foremost turning a `Series` to a `ChunkedArray` is effortless, thus we can use pattern matching to classify a Series' type, and based on data's type call the conversion function, for example, on `DataType::Boolean` branch, we could use `.bool()` method for conversion. After that, we need to store the temporary value from the ChunkedArray. However, due to `index` function's immutable reference, we cannot mutate the self state without using unsafe code. Accordingly, we can turn `&self.cache` into an immutable raw pointer, and then turn it to a mutable raw pointer, and finally use `unsafe` block to assign the temporary value to this mutable raw pointer. Finally, call `.as_ref()` to turn `&Box<dyn MyValueTrait>` into `&MyValue`.

```rust
impl<'a> Index<usize> for MySeriesIndexing<'a> {
    type Output = MyValue;

    fn index(&self, index: usize) -> &Self::Output {
        match self.data.dtype() {
            DataType::Boolean => {
                // unpack series to `ChunkedArray`
                let res: Box<dyn MyValueTrait> = match self.data.bool().unwrap().get(index) {
                    Some(v) => Box::new(v),
                    None => Box::new(Null),
                };

                // turn `cache` into an immutable raw pointer
                let r = &self.cache as *const Box<dyn MyValueTrait>;
                // turn immutable raw pointer into a mutable pointer
                let m = r as *mut Box<dyn MyValueTrait>;
                // assign result to mutable pointer
                unsafe { *m = res };

                self.cache.as_ref()
            }
            DataType::UInt8 => todo!(),
            DataType::UInt16 => todo!(),
            DataType::UInt32 => todo!(),
            DataType::UInt64 => todo!(),
            DataType::Int8 => todo!(),
            DataType::Int16 => todo!(),
            DataType::Int32 => todo!(),
            DataType::Int64 => {
                // directly call `.get` method, which has a runtime casting (less efficiency)
                // since we already use pattern matching on `self.data.dtype()`, this case
                // is only for demonstrating
                let res: Box<dyn MyValueTrait> = match self.data.get(index) {
                    AnyValue::Int64(v) => Box::new(v),
                    _ => Box::new(Null),
                };

                let r = &self.cache as *const Box<dyn MyValueTrait>;
                let m = r as *mut Box<dyn MyValueTrait>;
                unsafe { *m = res };

                self.cache.as_ref()
            }
            DataType::Float32 => todo!(),
            DataType::Float64 => todo!(),
            DataType::Utf8 => todo!(),
            _ => unimplemented!(),
        }
    }
}
```

And here comes the finally unit test:

```rust
#[test]
fn my_series_index_success() {
    let s = Series::new("funk", [true, false, true, true]);

    let s = MySeriesIndexing::new(&s);

    println!("{:?}", &s[1]);
    println!("{:?}", &s[3]);
}
```

and it gives us:

```txt
MyValue(false)
MyValue(true)
```

[unsafe code](https://github.com/Jacobbishopxy/jotting/blob/master/polars-prober/src/unsafe_index.rs)

## Safe Code

WIP

[code](https://github.com/Jacobbishopxy/jotting/blob/master/polars-prober/src/index.rs)
