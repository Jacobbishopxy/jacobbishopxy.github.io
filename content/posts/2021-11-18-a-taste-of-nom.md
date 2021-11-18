+++
title = "A taste of NOM"
description = "Parser combinator inception"
date = 2021-11-18

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

+++

## Intro

Recently, I've been working on a small project which entails parsing a string into some kind of data structure. `Regex` of course is the first coming up solution to me spontaneously, but as the time passed, I contemplated what if I could use a parser combinator to do the same thing. This is not a verbiage but a beneficial motive for the project's future expansion. Fortunately, few months ago I was intrigued by a parser combinator framework called [nom](https://github.com/Geal/nom), and at that moment I fortuitously read [the article](https://bodil.lol/parser-combinators/) provided by [Bodil Stokke](https://github.com/bodil). It grants me a immense pleasure to understand the concept of parser combinator. Some people may ask what can we do by this framework, and here I've listed some of the reasons 'Why use nom' from the official documentation:

> 1. Binary format parsers
> 2. Text format parsers
> 3. Programming language parsers
> 4. Streaming formats

Although, comparing to the list above, the use case of mine is a little bit lightweight, it inspired me a future scenario that is to deal with streaming parsing, such as huge files or network formats (the last use case on the list).

## Impl

Back to our topic, let's explore what 'nom' can do for us. This time, I used [List of parsers and combinators](https://github.com/Geal/nom/blob/main/doc/choosing_a_combinator.md) as a reference to surf the possibilities of composing. To include the [nom](https://crates.io/crates/nom) crate into your project, add the following line to your Cargo.toml:

```toml
[dependencies]
nom = "7"
```

To make things clear, let's start with an assumption: In a runtime environment, there is no preliminary connection information for the server side to know which database and table should be connected and read, hence we need a hot-reload mechanism to make sure that each time the request from the client side can be distinguished and then connect to a specific database and read an existed table afterward.

Suppose we have some strings like `[MYSQL:BOOLEAN]` and `[POSTGRES:CHAR]`, and we want to parse them into a `DbType` enum and a `ValueType` enum respectively. First, we need to define these two enum:

```rust
#[derive(Debug)]
pub(crate) enum DbType {
    Mysql,
    Postgres,
    Sqlite,
}

#[derive(Debug, PartialEq, Eq)]
pub(crate) enum ValueType {
    Bool,
    U8,
    U16,
    U32,
    U64,
    I8,
    I16,
    I32,
    I64,
    F32,
    F64,
    String,
}
```

And then, we want a `FromStr` trait for each of these enum, which will be used to parse the string into the corresponding enum. Additionally, an error enum is required for the `FromStr` trait:

```rust
#[derive(Debug)]
pub(crate) enum ParsingError {
    InvalidDbType,
    InvalidDataType,
}

impl FromStr for DbType {
    type Err = ParsingError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "MYSQL" => Ok(DbType::Mysql),
            "POSTGRES" => Ok(DbType::Postgres),
            "SQLITE" => Ok(DbType::Sqlite),
            _ => Err(ParsingError::InvalidDbType),
        }
    }
}
```

Wait, `FromStr` means a one-to-one binding, but we need many-to-many binding for the `ValueType`, for instance, in Mysql 'TINYINT(1)' and 'BOOLEAN' represent 'bool' in Rust, while in Postgres 'BOOL' also represents 'bool' in Rust, and moreover, 'TINYINT UNSIGNED' in Mysql represents 'u8' in Rust, while there is no such thing in Postgres, hence there is no way to impl a `FromStr` trait for `ValueType` enum that can manifest each variant.

One way to solve this problem is to define three static `HashMap` to store `&'static str` to `ValueType` mapping relationship:

```rust
lazy_static::lazy_static! {
    pub(crate) static ref MYSQL_TMAP: HashMap<&'static str, ValueType> = {
        HashMap::from([
            ("TINYINT(1)", ValueType::Bool),
            ("BOOLEAN", ValueType::Bool),
            ("TINYINT UNSIGNED", ValueType::U8),
            ("SMALLINT UNSIGNED", ValueType::U16),
            ("INT UNSIGNED", ValueType::U32),
            ("BIGINT UNSIGNED", ValueType::U64),
            ("TINYINT", ValueType::I8),
            ("SMALLINT", ValueType::I16),
            ("INT", ValueType::I32),
            ("BIGINT", ValueType::I64),
            ("FLOAT", ValueType::F32),
            ("DOUBLE", ValueType::F64),
            ("VARCHAR", ValueType::String),
            ("CHAR", ValueType::String),
            ("TEXT", ValueType::String),
        ])
    };

    pub(crate) static ref POSTGRES_TMAP: HashMap<&'static str, ValueType> = {
        HashMap::from([
            ("BOOL", ValueType::Bool),
            ("CHAR", ValueType::I8),
            ("TINYINT", ValueType::I8),
            ("SMALLINT", ValueType::I16),
            ("SMALLSERIAL", ValueType::I16),
            ("INT2", ValueType::I16),
            ("INT", ValueType::I32),
            ("SERIAL", ValueType::I32),
            ("INT4", ValueType::I32),
            ("BIGINT", ValueType::I64),
            ("BIGSERIAL", ValueType::I64),
            ("INT8", ValueType::I64),
            ("REAL", ValueType::F32),
            ("FLOAT4", ValueType::F32),
            ("DOUBLE PRECISION", ValueType::F64),
            ("FLOAT8", ValueType::F64),
            ("VARCHAR", ValueType::String),
            ("CHAR(N)", ValueType::String),
            ("TEXT", ValueType::String),
            ("NAME", ValueType::String),
        ])
    };

    pub(crate) static ref SQLITE_TMAP: HashMap<&'static str, ValueType> = {
        HashMap::from([
            ("BOOLEAN", ValueType::Bool),
            ("INTEGER", ValueType::I32),
            ("BIGINT", ValueType::I64),
            ("INT8", ValueType::I64),
            ("REAL", ValueType::F64),
            ("VARCHAR", ValueType::String),
            ("CHAR(N)", ValueType::String),
            ("TEXT", ValueType::String),
        ])
    };
}
```

Don't forget to include `lazy_static` crate to your Cargo.toml:

```toml
[dependencies]
lazy_static = "1"
```

And unit test is needed to test these three `HashMap`:

```rust
#[test]
fn test_get_tmap() {
    assert_eq!(MYSQL_TMAP.get("BIGINT UNSIGNED").unwrap(), &ValueType::U64);
    assert_eq!(POSTGRES_TMAP.get("REAL").unwrap(), &ValueType::F32);
    assert_eq!(SQLITE_TMAP.get("CHAR(N)").unwrap(), &ValueType::String);
}
```

Then we come to the most encouraging part, using 'nom' to parse strings like `[MYSQL:BOOLEAN]` and `[POSTGRES:CHAR]`. We want to extract two parts from these strings: database type and value type, and furthermore, characters `[`, `:` and `]` are the identifiers to delimitate these two types. According to the reference, [`alpha1`](https://docs.rs/nom/7.1.0/nom/character/complete/fn.alpha1.html) can be used to find out at least one alphabet character, and [`tag`](https://docs.rs/nom/7.1.0/nom/bytes/complete/fn.tag.html) can be used to recognizes a specific suite of characters or bytes.

Another thing that cannot be neglected is that database type and value type are separated by a colon, using `alpha1` and `tag` can barely help to extract them at once. Therefore, introducing a sequence combinator turns to be necessary. [`separated_pair`](https://docs.rs/nom/7.1.0/nom/sequence/fn.separated_pair.html) as the name suggests, will extract a pair of values from a sequence:

> Gets an object from the first parser, then matches an object from the sep_parser and discards it, then gets another object from the second parser.
>
> ```rust
> use nom::sequence::separated_pair;
> use nom::bytes::complete::tag;
>
> let mut parser = separated_pair(tag("abc"), tag("|"), tag("efg"));
>
> assert_eq!(parser("abc|efg"), Ok(("", ("abc", "efg"))));
> assert_eq!(parser("abc|efghij"), Ok(("hij", ("abc", "efg"))));
> assert_eq!(parser(""), Err(Err::Error(("", ErrorKind::Tag))));
> assert_eq!(parser("123"), Err(Err::Error(("123", ErrorKind::Tag))));
> ```

Finally, we need [`delimited`](https://docs.rs/nom/7.1.0/nom/sequence/fn.delimited.html) to matches the whole string:

> Matches an object from the first parser and discards it, then gets an object from the second parser, and finally matches an object from the third parser and discards it.
>
> ```rust
> use nom::sequence::delimited;
> use nom::bytes::complete::tag;
>
> let mut parser = delimited(tag("("), tag("abc"), tag(")"));
>
> assert_eq!(parser("(abc)"), Ok(("", "abc")));
> assert_eq!(parser("(abc)def"), Ok(("def", "abc")));
> assert_eq!(parser(""), Err(Err::Error(("", ErrorKind::Tag))));
> assert_eq!(parser("123"), Err(Err::Error(("123", ErrorKind::Tag))));
> ```

Omitting the attempting process, we can write a function as this:

```rust
fn get_types(input: &str) -> IResult<&str, (&str, &str)> {
    let sql_type = |s| alpha1(s);
    let data_type = |s| alpha1(s);

    let ctn = separated_pair(sql_type, tag(":"), data_type);
    let mut par = delimited(tag("["), ctn, tag("]"));

    par(input)
}
```

Then try the unit test:

```rust
#[test]
fn test_get_types() {
    assert_eq!(
        get_types("[MYSQL:BOOLEAN]").unwrap(),
        ("", ("MYSQL", "BOOLEAN"))
    );
    assert_eq!(
        get_types("[POSTGRES:DOUBLE PRECISION]").unwrap(),
        ("", ("POSTGRES", "DOUBLE PRECISION"))
    );
}
```

Sadly, it throws an error at the second assertion, because there has a space between `DOUBLE` and `PRECISION`.

...to be done
