+++
title = "A taste of NOM (II)"
description = "Parser combinator "
date = 2022-05-15

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

+++

## Intro

Hello everyone! It has been a while since I've written the last blog post, and today's topic is an extension of the previous [NOM parser combinator](@/posts/2021-11-18-a-taste-of-nom-i.md). The main idea is to create a custom error type for NOM, and makes it wrapped by a higher level enum type who serves a lib crate. From the previous post, we've learned that each NOM parser or combinator is a generic function who accepts generic types of input `I`, output `O` and error type `E`. Generally, we use the given type `IResult<I, O, E>` as our function's return type, and which means to let the compiler to determine the error type `E` for us. While we go deeper into the error type `E`, we will see that it is actually an enum `Err<E>` who carries a generic type `E`, and furthermore, the variant `Error(E)`, which denotes an recoverable error, should be the most common error type while we are coding. Briefly speaking, in my expectation, once we wrapped the `Err<E>` into custom error type and makes it to satisfy some requirements (implement several traits), we can use `?` operation in our functions to handle the error.

## Impl

Ok, let's see how the official example works with custom error type:

```rust
#[derive(Debug)]
pub struct CustomError(String);

impl<'a> From<(&'a str, ErrorKind)> for CustomError {
  fn from(error: (&'a str, ErrorKind)) -> Self {
    CustomError(format!("error code was: {:?}", error))
  }
}

impl<'a> ParseError<&'a str> for CustomError {
  fn from_error_kind(_: &'a str, kind: ErrorKind) -> Self {
    CustomError(format!("error code was: {:?}", kind))
  }

  fn append(_: &'a str, kind: ErrorKind, other: CustomError) -> Self {
    CustomError(format!("{:?}\nerror code was: {:?}", other, kind))
  }
}
```

Two implementations are required: the former one is a `From` trait which allows us to convert our custom error type from a tuple, whose first element is the input type `I` and the second element is an enum `ErrorKind` indicated which parser returned an error; the latter one is a `ParseError` trait which is required by the error type of a NOM parser. There are four methods in `ParseError<I>` trait:

```rust
pub trait ParseError<I>: Sized {
  /// Creates an error from the input position and an [ErrorKind]
  fn from_error_kind(input: I, kind: ErrorKind) -> Self;

  /// Combines an existing error with a new one created from the input
  /// position and an [ErrorKind]. This is useful when backtracking
  /// through a parse tree, accumulating error context on the way
  fn append(input: I, kind: ErrorKind, other: Self) -> Self;

  /// Creates an error from an input position and an expected character
  fn from_char(input: I, _: char) -> Self {
    Self::from_error_kind(input, ErrorKind::Char)
  }

  /// Combines two existing errors. This function is used to compare errors
  /// generated in various branches of `alt`.
  fn or(self, other: Self) -> Self {
    other
  }
}
```

From above, we know that `from_char` and `or` has default implementations, and the rest two methods `from_error_kind` and `append` has `Self` as their return type. Apparently, the easiest way for user to design a custom error type is to convert and save the incoming parameters `input: I` and `kind: ErrorKind` as `String`, which shown above as `pub struct CustomError(String)`.

Let's take a closer look on the following functions' signature to see the difference between default error type and custom error type:

```rust
fn test_with_default_error(input: &str) -> IResult<&str, &str> {
  tag("abcd")(input)
}

fn test_with_custom_error(input: &str) -> IResult<&str, &str, CustomError> {
  tag("abcd")(input)
}
```

With the custom error, we are explicitly telling the compiler that we want to use the custom error type `CustomError` instead of the default error type. The next question is how do we use it in our own `Result` type. First of all, we are going to create an enum type `TasteNomError` to handle variates errors, and don't forget a `From` trait for the further implicit conversion:

```rust
#[derive(Error, Debug)]
pub enum TasteNomError {
    #[error(transparent)]
    CustomNom(nom::Err<CustomError>),

    #[error("sql error: {0}")]
    Sql(String),

    #[error(transparent)]
    ParseInt(#[from] std::num::ParseIntError),
}

impl From<nom::Err<CustomError>> for TasteNomError {
    fn from(error: nom::Err<CustomError>) -> Self {
        TasteNomError::CustomNom(error)
    }
}
```

Here I imported a new dependency `thiserror`, which is a very useful tool when writing ones own lib crate. For more information, go visit [thiserror](https://docs.rs/thiserror/latest/thiserror/).

```toml
[dependencies]
thiserror = "1"
```

For a better demonstration, let's assume a real world problem is turning a Sql connection string `"mysql://root:root@localhost:3306/test"` into a struct `SqlConnInfo`:

```rust
#[derive(Debug, Clone)]
pub enum SqlBuilder {
    Mysql,
    Postgres,
    Sqlite,
}

impl FromStr for SqlBuilder {
    type Err = TasteNomError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "mysql" => Ok(SqlBuilder::Mysql),
            "postgres" => Ok(SqlBuilder::Postgres),
            "sqlite" => Ok(SqlBuilder::Sqlite),
            _ => Err(TasteNomError::Sql(format!("unknown database type: {}", s))),
        }
    }
}

#[derive(Debug)]
pub struct SqlConnInfo {
    pub driver: SqlBuilder,
    pub username: String,
    pub password: String,
    pub host: String,
    pub port: u32,
    pub database: String,
}

impl SqlConnInfo {
    pub fn new(
        driver: SqlBuilder,
        username: &str,
        password: &str,
        host: &str,
        port: u32,
        database: &str,
    ) -> SqlConnInfo {
        SqlConnInfo {
            driver,
            username: username.to_owned(),
            password: password.to_owned(),
            host: host.to_owned(),
            port,
            database: database.to_owned(),
        }
    }
}
```

This is quite a simple problem that we only need to split the string into serval parts like this patter `"{driver}://{username}:{password}@{host}:{port}/{database}"`. Just simply use `separated_pair` method is enough:

```rust
fn take_driver_and_rest(input: &str) -> IResult<&str, (&str, &str)> {
    separated_pair(alpha1, tag("://"), rest)(input)
}

fn take_username_and_rest(input: &str) -> IResult<&str, (&str, &str)> {
    separated_pair(alphanumeric1, tag(":"), rest)(input)
}

fn take_password_and_rest(input: &str) -> IResult<&str, (&str, &str)> {
    separated_pair(alphanumeric1, tag("@"), rest)(input)
}

fn take_host_and_rest(input: &str) -> IResult<&str, (&str, &str)> {
    separated_pair(alpha1, tag(":"), rest)(input)
}

fn take_port_and_database(input: &str) -> IResult<&str, (&str, &str)> {
    separated_pair(digit1, tag("/"), rest)(input)
}
```

And their unit tests:

```rust
#[test]
fn driver_and_rest() {
    let foo = take_driver_and_rest("mysql://root:root@localhost:3306/test");
    assert!(foo.is_ok());
}

#[test]
fn username_and_rest() {
    let foo = take_username_and_rest("root:root@localhost:3306/test");
    assert!(foo.is_ok());
}

#[test]
fn password_and_rest() {
    let foo = take_password_and_rest("root@localhost:3306/test");
    assert!(foo.is_ok());
}

#[test]
fn host_and_rest() {
    let foo = take_host_and_rest("localhost:3306/test");
    assert!(foo.is_ok());
}

#[test]
fn port_and_db() {
    let foo = take_port_and_database("3306/test");
    assert!(foo.is_ok());
}
```

Now, we can combine them together:

```rust
type ResultInfo1<'a> = (&'a str, (&'a str, (&'a str, (&'a str, (&'a str, &'a str)))));

fn get_conn_info1(value: &str) -> IResult<&str, ResultInfo1, CustomError> {
    let f_port_and_database = separated_pair(digit1, tag("/"), alphanumeric1);
    let f_host_and_rest = separated_pair(alpha1, tag(":"), f_port_and_database);
    let f_password_and_rest = separated_pair(alphanumeric1, tag("@"), f_host_and_rest);
    let f_username_and_rest = separated_pair(alphanumeric1, tag(":"), f_password_and_rest);
    let mut f_driver_and_rest = separated_pair(alpha1, tag("://"), f_username_and_rest);

    f_driver_and_rest(value)
}
```

or:

```rust
type ResultInfo2<'a> = (&'a str, ((&'a str, &'a str), ((&'a str, &'a str), &'a str)));

fn get_conn_info2(value: &str) -> IResult<&str, ResultInfo2, CustomError> {
    let f_host_and_port = separated_pair(alpha1, tag(":"), digit1);
    let f_address_and_database = separated_pair(f_host_and_port, tag("/"), alphanumeric1);
    let f_username_and_password = separated_pair(alphanumeric1, tag(":"), alphanumeric1);
    let f_user_and_rest = separated_pair(f_username_and_password, tag("@"), f_address_and_database);
    let mut f_driver_and_rest = separated_pair(alpha1, tag("://"), f_user_and_rest);

    f_driver_and_rest(value)
}
```

The next thing is to use our own `Result<T, TasteNomError>` instead of `IResult<&str, T, CustomError>`. Before we heading further, let's do a little work to make sure that the extracted `&str` patterns can be converted to `SqlConnInfo`:

```rust
type ConnStrPattern<'a> = (
    &'a str,
    (&'a str, ((&'a str, &'a str), ((&'a str, &'a str), &'a str))),
);

impl<'a> TryFrom<ConnStrPattern<'a>> for SqlConnInfo {
    type Error = TasteNomError;

    fn try_from(source: ConnStrPattern<'a>) -> Result<Self, Self::Error> {
        let (_, (driver, ((username, password), ((host, port), database)))) = source;

        Ok(Self::new(
            SqlBuilder::from_str(driver)?,
            username,
            password,
            host,
            port.parse::<u32>()?,
            database,
        ))
    }
}
```

Finally, here comes the final step:

```rust
type GeneralResult<T> = Result<T, TasteNomError>;

fn get_conn_info3(value: &str) -> GeneralResult<SqlConnInfo> {
    let f_host_and_port = separated_pair(take_until1(":"), tag(":"), digit1);
    let f_address_and_database = separated_pair(f_host_and_port, tag("/"), alphanumeric1);
    let f_username_and_password = separated_pair(alphanumeric1, tag(":"), alphanumeric1);
    let f_user_and_rest = separated_pair(f_username_and_password, tag("@"), f_address_and_database);
    let mut f_driver_and_rest = separated_pair(alpha1, tag("://"), f_user_and_rest);

    let res = f_driver_and_rest(value)?;

    SqlConnInfo::try_from(res)
}
```

Thanks to what we did before: `impl From<nom::Err<CustomError>> for TasteNomError`, which let us to use `?` operation to convert `nom::Err<CustomError>` to `TasteNomError`. after being through all the works, the line `let res = f_driver_and_rest(value)?;` finally can be compiled!

Don't forget the unit test:

```rust
fn conn_info() {
  const CONN1: &str = "mysql://root:root@localhost:3306/test";
  const CONN2: &str = "mysql://root:root@127.0.0.1:3306/test";

  let foo = get_conn_info3(CONN1);
  assert!(foo.is_ok());

  let foo = get_conn_info3(CONN2);
  assert!(foo.is_ok());
}
```

The full code is in my Github page [custom_error.rs](https://github.com/Jacobbishopxy/jotting/blob/master/taste-nom/src/custom_error.rs) and [database_conn.rs](https://github.com/Jacobbishopxy/jotting/blob/master/taste-nom/src/database_conn.rs), and you are more than welcome to leave a message for me. That's all for today, until next time! :wave:
