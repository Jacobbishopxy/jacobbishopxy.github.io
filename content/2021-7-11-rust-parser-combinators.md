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

## 测试 Parser

```rs
#[test]
fn literal_parser() {
    let parse_joe = match_literal("Hello Joe!");
    assert_eq!(Ok(("", ())), parse_joe("Hello Joe!"));
    assert_eq!(
        Ok((" Hello Robert!", ())),
        parse_joe("Hello Joe! Hello Robert!")
    );
    assert_eq!(Err("Hello Mike!"), parse_joe("Hello Mike!"));
}
```

## 泛用性更高的 Parser

现在让我们解析 `<`，`>`，`=`，以及 `</` 与 `/>`。使用正则表达式的 crate 来解决问题固然简单，但实际上我们并不需要这么做。让我们尝试只用 Rust 标准库来完成这个任务。回忆一下鉴别元素名的规则：一个字母字符，紧接着是零或是更多的字母字符，一个数字，或者一个破折号 `-`。

```rs
fn identifier(input: &str) -> Result<(&str, String), &str> {
    let mut matched = String::new();
    let mut chars = input.chars();

    match chars.next() {
        Some(next) if next.is_alphabetic() => matched.push(next),
        _ => return Err(input),
    }

    while let Some(next) = chars.next() {
        if next.is_alphabetic() || next == '-' {
            matched.push(next);
        } else {
            break;
        }
    }

    let next_index = matched.len();
    Ok((&input[next_index..], matched))
}
```

按照惯例，我们首先查看类型。这次我们编写的不再是一个用于构建 Parser 的函数，而是 Parser 本身，与第一个例子类似。它们最大的差别在于这次的返回类型不再是 `()`，而是一个 `String`。该 `String` 则包含了被解析过后的 identifier。

`matched` 作为返回值的一部分被初始化。`chars` 的类型为 `Chars`，是一个字符的迭代器。

第一步，解析第一个字符（`.is_alphabetic` 由标准库提供），如果是字母则放入 `matched`，否则直接返回错误。

第二步，持续提取 chars 的字符，如果为字母或者 `-` 便放入 `matched`，否则退出迭代。换言之，当第一次遇到不匹配的情形也就意味着我们结束解析，那么最后的返回值便是解析的剩余部分与已解析部分的元组。

这里值得注意的是，当我们匹配到不是字母或 `-` 时，我们并不返回一个错误。

接下来是测试：

```rs
#[test]
fn identifier_parser() {
    assert_eq!(
        Ok(("", "i-am-an-identifier".to_string())),
        identifier("i-am-an-identifier")
    );
    assert_eq!(
        Ok((" entirely an identifier", "not".to_string())),
        identifier("not entirely an identifier")
    );
    assert_eq!(
        Err("!not at all an identifier"),
        identifier("!not at all an identifier")
    );
}
```

## 组合子 Combinators

现在我们可以解析初始字符 `<`，同样也可以解析之后的 identifier，但是我们需要有序的解析。因此下一步就是编写另一个 parser 构造函数，不同的是接收两个 parser 作为输入并返回一个新的 parser，其功能是有序的进行解析。换言之，一个 parser combinator，因为它组合两个 parser 称为一个新的 parser。

```rs
fn pair<P1, P2, R1, R2>(
    parser1: P1,
    parser2: P2,
) -> impl Fn(&str) -> Result<(&str, (R1, R2)), &str>
where
    P1: Fn(&str) -> Result<(&str, R1), &str>,
    P2: Fn(&str) -> Result<(&str, R2), &str>,
{
    move |input| match parser1(input) {
        Ok((next_input, result1)) => match parser2(next_input) {
            Ok((final_input, result2)) => Ok((final_input, (result1, result2))),
            Err(err) => Err(err),
        },
        Err(err) => Err(err),
    }
}
```

这里变得稍微有点复杂了，但是一如既往，首先开始观察类型。

首先是四个类型变量：`P1`，`P2`，`P1` 和 `P2`，即 Parser 1，Parser 2，Result 1 和 Result 2。`P1` 和 `P2` 作为函数，可以观察到它们遵从 parser 函数的模式：`&str` 作为输入，并返回一个包含解析的剩余部分与已解析部分的元组 `Result`，或是一个错误。

再观察每个函数的返回类型：`P1` 是一个 parser 成功时返回 `R1`，同样的 `P2` 生产 `R2`。以及最终的 parser 的返回 -- 即由函数所返回的函数 -- 为 `(R1, R2)`。因此该 parser 的任务便是首先运行 `P1`，保留其结果，接着用 `P1` 的返回值作为输入运行 `P2`，如果它们都没有错误，我们结合两个返回成为一个元组 `(R1, R2)`。

按照这样的方式，我们就可以结合之前写的两个 parser 了，`match_literal` 和 `identifier`。现在先看看测试：

```rs
#[test]
fn pair_combinator() {
    let tag_opener = pair(match_literal("<"), identifier);

    assert_eq!(
        Ok(("/>", ((), "my-first-element".to_string()))),
        tag_opener("<my-first-element/>")
    );
    assert_eq!(Err("oops"), tag_opener("oops"));
    assert_eq!(Err("!oops"), tag_opener("<!oops"));
}
```

它看起来没问题！但是再看看返回类型：`((), String)`。很明显我们只关注到了返回右边的值，即 `String`。这种情况很常见 —— 有些解析器只匹配输入中的模式，而不产生值，因此可以安全地忽略它们的输出。为了适应这种模式，我们将要使用 `pair` 组合子来编写两个其它的组合子：`left`，它丢弃第一个 parser 的返回并仅返回第二个 parser 的结果，与之相反的是 `right`，它是以上例子所希望使用的类型而不是 `pair` -- 即丢弃了左值 `()` 并保留 `String`。

## 函子 Functor

进一步的研究之前，介绍一下另一个组合子，它可以使编写变得更轻松：`map`。

这个组合子有一个目的：转变结果的类型。举个例子，如果有一个 parser 返回的是 `((), String)`，你希望转换其成为 `String`。

为了达到这个目的，我们需要传入一个知道如何转换类型的函数。我们的例子需要的是：`|(_left, right)| right`。抽象来说，它跟像是 `Fn(A) -> B`，其中 `A` 是 parser 生产的原始类型，而 `B` 则是新的类型。

```rs
fn _map<P, F, A, B>(parser: P, map_fn: F) ->
    impl Fn(&str) -> Result<(&str, B), &str>
where
    P: Fn(&str) -> Result<(&str, A), &str>,
    F: Fn(A) -> B,
{
    move |input| match parser(input) {
        Ok((next_input, result)) => Ok((next_input, map_fn(result))),
        Err(err) => Err(err),
    }
}
```

那么类型告诉了我们什么呢？`P` 是我们的 parser，成功时它返回 `A`。`F` 作为函数将被用作于映射（map） `P` 的返回值，即转化 `A` 成为 `B`。

实际上，我们可以简化一下该函数，因为 `map` 其实是一个通用模式，它已经被 `Result` 实现过了：

```rs
pub fn map<P, F, A, B>(parser: P, map_fn: F) ->
    impl Fn(&str) -> Result<(&str, B), &str>
where
    P: Fn(&str) -> Result<(&str, A), &str>,
    F: Fn(A) -> B,
{
    move |input| parser(input)
        .map(|(next_input, result)| (next_input, map_fn(result)))
}
```

这种模式在 Haskell 中被称之为一个“函子” functor，同时它拥有数学上的兄弟，范畴论 category theory。如果有一个类型 `A`，以及一个 `map` 函数可以接收一个 `A` 转换为 `B` 的函数，那么这便是一个函子。在 Rust 中可以经常见到它，例如 `Option`，`Result`，`Iterator` 甚至是 `Future`，只不过它们没有被显式的被称为函子。原因也很简单：你不能如同 Rust 的类型系统那样，真正的去表达一个函子，因为 Rust 缺少高阶类型 Higher kinded types，不过这就是另一件事儿了。

## Trait 出场

你或许注意到了迄今为止我们一直重复提到的 parser 类型签名：`Fn(&str) -> Result<(&str, Output), &str>`。用 trait 可以提高可读性，但是首先我们可以为返回值加上一个类型别名：

```rs
type ParseResult<'a, Output> = Result<(&'a str, Output), &'a str>;
```

这里的生命周期 `'a`，具体指的是输入的生命周期。

现在定义 trait。我们需要把生命周期也放入 trait 中，当你使用 trait 时，都需要这个生命周期。

```rs
trait Parser<'a, Output> {
    fn parse(&self, input: &'a str) -> ParseResult<'a, Output>;
}
```

该 trait 现在暂时只有一个方法：`parse()`，正如我们之前 parser 的函数签名那样。为了让事情变得更加简单，我们可以为任何匹配该签名的 parser 函数来实现这个 trait。

```rs
impl<'a, F, Output> Parser<'a, Output> for F
where
    F: Fn(&'a str) -> ParseResult<Output>,
{
    fn parse(&self, input: &'a str) -> ParseResult<'a, Output> {
        self(input)
    }
}
```

通过这种方式，我们不仅可以自有的使用实现了 Parser trait 的函数，还打开了其它的可能性，即使用其它作为 parser 的类型。

但是更重要的是，它节省了重复编写函数签名的时间。现在让我们重写 `map` 函数：

```rs
fn map<'a, P, F, A, B>(parser: P, map_fn: F) -> impl Parser<'a, B>
where
    P: Parser<'a, A>,
    F: Fn(A) -> B,
{
    move |input| {
        parser
            .parse(input)
            .map(|(next_input, result)| (next_input, map_fn(result)))
    }
}
```

这里特别需要注意的是：不再直接作为一个函数来调用 parser，我们现在需要 `parser.parse(input)`，因为我们不知道 `P` 是否为一个函数，仅仅是知道它实现了 `Parser`，因此我们需要使用 `Parser` 接口所提供的函数。这么做的话，函数体会看起来完全一样，同时类型看起来更为简洁。这里虽然有生命周期 `'a` 这个噪音，但是整体上有一个很大的提升。

那么现在让我们重写 `pair` 函数，现在它看起来更加的简洁了：

```rs
fn pair<'a, P1, P2, R1, R2>(parser1: P1, parser2: P2) ->
    impl Parser<'a, (R1, R2)>
where
    P1: Parser<'a, R1>,
    P2: Parser<'a, R2>,
{
    move |input| match parser1.parse(input) {
        Ok((next_input, result1)) => match parser2.parse(next_input) {
            Ok((final_input, result2)) => Ok((final_input, (result1, result2))),
            Err(err) => Err(err),
        },
        Err(_) => todo!(),
    }
}
```

同样的：仅有改变的地方是类型签名更加整洁以及使用的是 `parser.parse(input)` 而不是 `parser(input)`。

实际上我们还可以进一步简化函数：

```rs
fn pair<'a, P1, P2, R1, R2>(parser1: P1, parser2: P2) ->
    impl Parser<'a, (R1, R2)>
where
    P1: Parser<'a, R1>,
    P2: Parser<'a, R2>,
{
    move |input| {
        parser1.parse(input).and_then(|(next_input, result1)| {
            parser2
                .parse(next_input)
                .map(|(last_input, result2)| (last_input, (result1, result2)))
        })
    }
}
```

`Result` 的 `and_then` 方法与 `map` 类似，不同的是该映射函数不返回新的类型传入 `Result`，而是一个新结合好的 `Result`。之后会再讲 `and_then`，现在让我们看看 `left` 和 `right` 的组合子如何实现。

## Left 和 Right

`pair` 与 `map` 实现了后再写 `left` 和 `right` 就简单多了：

```rs
fn left<'a, P1, P2, R1, R2>(parser1: P1, parser2: P2) ->
    impl Parser<'a, R1>
where
    P1: Parser<'a, R1>,
    P2: Parser<'a, R2>,
{
    map(pair(parser1, parser2), |(left, _)| left)
}

fn right<'a, P1, P2, R1, R2>(parser1: P1, parser2: P2) ->
    impl Parser<'a, R2>
where
    P1: Parser<'a, R1>,
    P2: Parser<'a, R2>,
{
    map(pair(parser1, parser2), |(_, right)| right)
}
```

我们使用 `pair` 组合子来组合两个 parser 成为一个返回两者元组的 parser，接着我们使用 `map` 组合子从元组中来选择所期望的值。

重写`match_literal`：

```rs
pub fn match_literal<'a>(expected: &'static str) -> impl Parser<'a, ()> {
    move |input: &'a str| match input.get(0..expected.len()) {
        Some(next) if next == expected => Ok((&input[expected.len()..], ())),
        _ => Err(input),
    }
}
```

对于闭包的入参而言，我们需要显式声明 `&'a str`。对于 `identifier` 而言，我们只需要用 `ParserResult<String>` 替换函数签名的返回类型。

现在的测试，不再需要毫无必要的 `()` 结果了：

```rs
#[test]
fn right_combinator() {
    let tag_opener = right(match_literal("<"), identifier);

    assert_eq!(
        Ok(("/>", "my-first-element".to_string())),
        tag_opener.parse("<my-first-element/>")
    );
    assert_eq!(Err("oops"), tag_opener.parse("oops"));
    assert_eq!(Err("!oops"), tag_opener.parse("<!oops"));
}
```

## One Or More

现在我们有了 `<`，有了 identifier，接下来需要什么呢？one or more 的 parser（为了应付一个或多个空格等正确的语法结构）！

其实我们在 `identifier` parser 已经做过这样的处理了，但是都是手动实现的。不必惊讶，通用性的实现并不困难。

```rs
pub fn one_or_more<'a, P, A>(parser: P) -> impl Parser<'a, Vec<A>>
where
    P: Parser<'a, A>,
{
    move |mut input| {
        let mut result = Vec::new();

        if let Ok((next_input, first_item)) = parser.parse(input) {
            input = next_input;
            result.push(first_item);
        } else {
            return Err(input);
        }

        while let Ok((next_input, next_item)) = parser.parse(input) {
            input = next_input;
            result.push(next_item);
        }

        Ok((input, result))
    }
}
```

首先，我们构建的解析器的返回类型是 A，组合 parser 的返回类型是 Vec -- 任意数量的 A。

代码看起来确实很像 `identifier`。首先我们解析第一个元素，如果不成功返回一个错误。接着我们解析尽可能多的元素，直到解析错误，返回已收集的元素。

那么 zero or more 呢？我们只需要移除第一个元素的解析：

```rs
fn zero_or_more<'a, P, A>(parser: P) -> impl Parser<'a, Vec<A>>
where
    P: Parser<'a, A>,
{
    move |mut input| {
        let mut result = Vec::new();

        while let Ok((next_input, next_item)) = parser.parse(input) {
            input = next_input;
            result.push(next_item);
        }

        Ok((input, result))
    }
}
```

接下来是测试：

```rs
#[test]
fn one_or_more_combinator() {
    let parser = one_or_more(match_literal("ha"));
    assert_eq!(Ok(("", vec![(), (), ()])), parser.parse("hahaha"));
    assert_eq!(Err("ahah"), parser.parse("ahah"));
    assert_eq!(Err(""), parser.parse(""));
}

#[test]
fn zero_or_more_combinator() {
    let parser = zero_or_more(match_literal("ha"));
    assert_eq!(Ok(("", vec![(), (), ()])), parser.parse("hahaha"));
    assert_eq!(Ok(("ahah", vec![])), parser.parse("ahah"));
    assert_eq!(Ok(("", vec![])), parser.parse(""));
}
```

注意它们两者的区别：对于 `one_or_more`，查找一个空字符串是错误的，因为它需要为其 sub-parser 查看至少一个元素，而对于 `zero_or_more`，空字符串意味着零状况，也就不是一个错误。

此刻我们有理由开始思考如何抽象这两个函数，因为一个函数完全是另一个函数的拷贝，仅仅只是去掉了一小部分。

## 谓语组合子 Predicate combinator

Under construction...
