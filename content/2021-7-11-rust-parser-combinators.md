+++
title = "Rust Parser Combinators"
date = 2021-07-11

[taxonomies]
tags = ["Rust", "FP", "Note"]

+++

学习笔记：[通过 Rust 学习组合子](https://bodil.lol/parser-combinators/)

## XML 风格的标记语言

以下一个简单版本的 XML：

```xml
<parent-element>
    <single-element attribute="value" />
</parent-element>
```

在 Rust 中可以构造以下的结构体用于描述 XML：

```rs
#[derive(Clone, Debug, PartialEq, Eq)]
struct Element {
    name: String,
    attributes: Vec<(String, String)>,
    children: Vec<Element>,
}
```

## 定义 Parser

Parsing 意为从流数据中获取结构的一个过程。Parser 则是梳理该结构的工具。

以函数的方式表达 Parser 就像这样：

```rs
Fn(Input) -> Result<(Input, Output), Error>
```

而我们的例子可以具体描述成这样：

```rs
Fn(&str) -> Result<(&str, Element), &str>
```

在这里使用字符串切片，是因为它是一个高效的字符串指针。我们可以根据需要来进一步切分它，通过切分掉已解析的部分，并返回剩余的部分作为结果。

使用 `&[u8]`（字节切片，如果只使用 ASCII 码可视为字符）作为输入类型，可能会更加的简洁。尤其是因为字符串切片与其他类型切片大有不同 -- 特别是你不可以通过类似 `input[0]` 这样下标的方式来索引，而是需要使用另一个切片 `input[0..1]`。另一方面使用字节切片来解析字符串会少了很多有效的方法。

## 第一个 Parser

编写一个字母 `a` 的 Parser。该 Parser 解析字符串切片的首元素，若为 'a' 则结果为 'a' 之后的所有切片的成功返回，反之则是包含自身的错误返回。

```rs
fn the_letter_a(input: &str) -> Result<(&str, ()), &str> {
    match input.chars().next() {
        Some('a') => Ok((&input['a'.len_utf8()..], ())),
        _ => Err(input),
    }
}
```

## 一个 Parser 构造器

现在编写一个函数用于生产 Parser，其作用于任何长度的静态字符串而不是仅作用于单个字符。该函数作为高阶函数 HOF（higher order function），返回一个闭包用作于解析。

```rs
fn match_literal(expected: &'static str) ->
    impl Fn(&str) -> Result<(&str, ()), &str>
{
    move |input| match input.get(0..expected.len()) {
        Some(next) if next == expected => {
            Ok((&input[expected.len()..], ()))
        }
        _ => Err(input),
    }
}
```
