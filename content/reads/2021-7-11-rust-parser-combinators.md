+++
title = "Rust 组合子"
description = "学习笔记"
date = 2021-07-11

[taxonomies]
categories = ["Read"]
tags = ["Rust", "FP"]

[extra]
toc = true

+++

**学习笔记：[通过 Rust 学习组合子](https://bodil.lol/parser-combinators/)**

组合子的概念在函数式编程中广为人知。而作为系统级的编程语言，Rust 更像是一门面向过程式的语言。因此在 Rust 上使用 FP 技巧并不如天生的那些 FP 语言有优势（大名鼎鼎 Haskell，以及 Scala 等）。例如缺少高阶类型 higher kinded type 支持等。

本文性质为阅读原文的笔记，其实更像是精简后的翻译。阅读原文前需要掌握一定的 FP 技巧，以及熟悉 Rust 语言。

**目录：**

- <a href="#XML 风格的标记语言">XML 风格的标记语言</a>
- <a href="#定义 Parser">定义 Parser</a>
- <a href="#第一个 Parser">第一个 Parser</a>
- <a href="#一个 Parser 构造器">一个 Parser 构造器</a>
- <a href="#测试 Parser">测试 Parser</a>
- <a href="#泛用性更高的 Parser">泛用性更高的 Parser</a>
- <a href="#组合子 Combinators">组合子 Combinators</a>
- <a href="#函子 Functor">函子 Functor</a>
- <a href="#Trait 出场">Trait 出场</a>
- <a href="#Left 和 Right">Left 和 Right</a>
- <a href="#One Or More">One Or More</a>
- <a href="#谓语组合子 Predicate combinator">谓语组合子 Predicate combinator</a>
- <a href="#引用字符串">引用字符串</a>
- <a href="#解析属性">解析属性</a>
- <a href="#很接近了">很接近了</a>
- <a href="#超越无限 To Infinity And Beyond">超越无限 To Infinity And Beyond</a>
- <a href="#展示自己的机会 BoxedParser">展示自己的机会 BoxedParser</a>
- <a href="#带子元素的情况">带子元素的情况</a>
- <a href="#是你讲那个 M 词还是由我来讲呢">是你讲那个 M 词还是由我来讲呢</a>
- <a href="#空格 Redux">空格 Redux</a>
- <a href="#终于完成了">终于完成了</a>
- <a href="#额外的资源">额外的资源</a>

<div id="XML 风格的标记语言"/>

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

<div id="定义 Parser"/>

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

<div id="第一个 Parser"/>

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

<div id="一个 Parser 构造器"/>

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

<div id="测试 Parser"/>

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

<div id="泛用性更高的 Parser"/>

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

<div id="组合子 Combinators"/>

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

<div id="函子 Functor"/>

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
fn map<P, F, A, B>(parser: P, map_fn: F) ->
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

<div id="Trait 出场"/>

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

<div id="Left 和 Right"/>

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
fn match_literal<'a>(expected: &'static str) -> impl Parser<'a, ()> {
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

<div id="One Or More"/>

## One Or More

现在我们有了 `<`，有了 identifier，接下来需要什么呢？one or more 的 parser（为了应付一个或多个空格等正确的语法结构）！

其实我们在 `identifier` parser 已经做过这样的处理了，但是都是手动实现的。不必惊讶，通用性的实现并不困难。

```rs
fn one_or_more<'a, P, A>(parser: P) -> impl Parser<'a, Vec<A>>
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

<div id="谓语组合子 Predicate combinator"/>

## 谓语组合子 Predicate combinator

我们现在有了解析空格的 `one_or_more` 以及解析属性对 attribute pairs 的 `zero_or_more`。

实际上我们并不是真的像解析空格再解析属性。试想一下，如果没有属性，那么空格便成为了可选的，这样我们将会立刻遇到 `>` 或是 `/>`。如果有一个属性，那么就必须要现有空格。幸运的是如果有多个属性，每个属性之间也必须为空格，因此我们这里真正考察的是一系列的 _zero or more_ 出现 _one or more_ 空格，再紧跟着的是属性。

我们首先需要一个 parser 用于解析单个空格。这里有三种方法。

第一，我们可以笨拙的使用 `match_literal` parser 带有一个字符串仅包含单个空格。为什么笨拙呢？因为空格也代表着换行，tabs，以及很多奇怪的 Unicode 字符渲染而成空格。我们将再次依赖 Rust 标准库，因为 `char` 拥有一个 `is_whitespace` 方法正如 `is_alphabetic` 与 `is_alphanumeric`。

第二，我们可以编写一个 parser 用于消费任何数量的空格字符，通过 `is_whitespace` 谓语的方式更像是早期写的 `identifier` 那样。

第三，我们可以编写一个 parser 名为 `any_char`，只要输入中不再剩余，它返回就单个 `char`。以及一个组合子 `pred`，它接收一个 parser 以及一个谓语函数，并像是这样把它们组合起来：`pred(any_char, |c| c.is_whitespace())`。这样拥有了额外的好处，使得编写最终的 parser 变得简单：属性值的引用字符串。

`any_char` parser 简单直接，但是我们需要注意的是那些 UTF-8 陷阱：

```rs
fn any_char(input: &str) -> ParseResult<char> {
    match input.chars().next() {
        Some(next) => Ok((&input[next.len_utf8()..], next)),
        _ => Err(input)
    }
}
```

`pred` 组合子同样也不复杂。唤起 `parser`，如果解析成功则对该值调用谓语函数，只有当返回 true 时，我们才真正返回 `success`，否则我们将返回与 parser 失败一样的错误。

```rs
fn pred<'a, P, A, F>(parser: P, predicate: F) -> impl Parser<'a, A>
where
    P: Parser<'a, A>,
    F: Fn(&A) -> bool,
{
    move |input| {
        if let Ok((next_input, value)) = parser.parse(input) {
            if predicate(&value) {
                return Ok((next_input, value));
            }
        }
        Err(input)
    }
}
```

接着是测试：

```rs
#[test]
fn predicate_combinator() {
    let parser = pred(any_char, |c| *c == 'o');
    assert_eq!(Ok(("mg", 'o')), parser.parse("omg"));
    assert_eq!(Err("lol"), parser.parse("lol"));
}
```

现在 `parser` 和 `pred` 都准备好了，我们可以编写 `whitespace_char` parser 了：

```rs
fn whitespace_char<'a>() -> impl Parser<'a, char> {
    pred(any_char, |c| c.is_whitespace())
}
```

有了 `whitespace_char` 以后我们便可以表达 _one or more_ 空格，以及它的姊妹概念，_zero or more_ 空格：

```rs
fn space1<'a>() -> impl Parser<'a, Vec<char>> {
    one_or_more(whitespace_char())
}

fn space0<'a>() -> impl Parser<'a, Vec<char>> {
    zero_or_more(whitespace_char())
}
```

<div id="引用字符串"/>

## 引用字符串

做了那么多准备工作后，现在是否至少能解析属性呢？当然没问题，我们仅需要确保拥有了所有独立的 parser。处理属性名称的 `identifier` 有了，处理 `=` 号的 `match_literal("=")` 也有了。现在还缺少一个字符串 parser。幸运的是我们已经拥有了所有的组合子：

```rs
fn quoted_string<'a>() -> impl Parser<'a, String> {
    map(
        right(
            match_literal("\""),
            left(
                zero_or_more(pred(any_char, |c| *c != '"')),
                match_literal("\""),
            ),
        ),
        |chars| chars.into_iter().collect(),
    )
}
```

组合子的嵌套看起来会有点讨厌，不过之后我们将重构它。现在让我们关注函数的本身。

最外层的组合子为 `map`，而它真实开始的地方是第一个引用字符。`map` 包含了一个 `right`，`right` 的第一部分即是我们所寻找的：`match_literal("\"")`，即引用的开头。

`right` 的第二部分则是字符串剩余的部分。它们被放入 `left` 中，我们很快就可以发现 `left` 的 _right_ 参数使我们一直忽视的另一个 `match_literal("\"")` -- 即引号结束。因此 _left_ 才是我们引用的字符串。

使用新的 pred 和 any_char 来获取一个接受除去另一个引号的任何内容的 parser，并将其放入 zero_or_more 中，因此实现如下：

- 一个引号
- 紧接着是零个或多个元素，它们都不为引号
- 紧接着是另一个引号

在 `right` 和 `left` 之间，我们丢弃结果值中的引号，并获得引用的字符串。

这个返回并不是一个字符串。还记得 `zero_or_more` 的返回么？是一个 `Vec<A>`，其中 `A` 是内部 parser 的返回值的类型。对于 `any_char` 而言则是 `char`。因此这里我们拿到的是 `Vec<char>`。这便是 `map` 所带来的：它将一个 `Vec<Char>` 转换成一个 `String`，借由 `Iterator<Item = char>` 迭代器所构建出 `String`，因此我们可以简单的使用上 `vec_of_chars.into_iter().collect()`，以及感谢类型接口的力量，我们拥有了 `String`。

接下来编写测试：

```rs
#[test]
fn quoted_string_parser() {
    assert_eq!(
        Ok(("", "Hello Joe!".to_string())),
        quoted_string().parse("\"Hello Joe!\"")
    );
}
```

这下子终于可以解析属性了。

<div id="解析属性"/>

## 解析属性

我们现在可以解析空格，标识符，`=` 号以及引用字符串。终于集齐了所有的 parser 了。

首先，让我们为一对属性编写一个 parser。我们将要以 `Vec<(String, String)>` 存储它们，这很像是需要 `(String, String)` 输入 `zero_or_more` 组合子的一个 parser。让我们看一下如何构建它。

```rs
fn attribute_pair<'a>() -> impl Parser<'a, (String, String)> {
    pair(identifier, right(match_literal("="), quoted_string()))
}
```

总结一下：我们已经拥有了处理一对值的 parser，`pair`，因此我们通过 `identifier` parser 生产一个 `String`，以及一个带有 `=` 号的 `right`，用于处理不需要保留的值，然后用 `quoted_string` parser，获取另一个 `String`。

现在让我们结合 `zero_or_more` 来构建 vector -- 不过也不要忘记它们之间的空格。

```rs
fn attributes<'a>() -> impl Parser<'a, Vec<(String, String)>> {
    zero_or_more(right(space1(), attribute_pair()))
}
```

zero or more 出现在这些情况：one or more 空格字符，接着一个属性对（attribute pair）。使用 `right` 来丢弃空格并保存属性对。

测试一下：

```rs
#[test]
fn attribute_parser() {
    assert_eq!(
        Ok((
            "",
            vec![
                ("one".to_string(), "1".to_string()),
                ("two".to_string(), "2".to_string())
            ]
        )),
        attributes().parse(" one=\"1\" two=\"2\"")
    );
}
```

<div id="很接近了"/>

## 很接近了

现在已经很接近我们的目标了，因为我们的类型也快速的接近了 NP 完整性。我们现在仅需要处理两种类型的元素标签：单个元素，和父子元素。

现在让我们从单个元素开始，看一下我们是否可以通过一些组合子的结合来获取 `(String, Vec<(String, String)>)` 类型的答案。

```rs
fn element_start<'a>() -> impl Parser<'a, (String, Vec<(String, String)>)> {
    right(match_literal("<"), pair(identifier, attributes()))
}
```

有了它我们便可以为单个元素编写一个 parser 了。

```rs
fn single_element<'a>() -> impl Parser<'a, Element> {
    map(
        left(element_start(), match_literal("/>")),
        |(name, attributes)| Element {
            name,
            attributes,
            children: vec![],
        },
    )
}
```

测试：

```rs
#[test]
fn single_element_parser() {
    assert_eq!(
        Ok((
            "",
            Element {
                name: "div".to_string(),
                attributes: vec![("class".to_string(), "float".to_string())],
                children: vec![]
            }
        )),
        single_element().parse("<div class=\"float\"/>")
    );
}
```

`single_element` 的返回类型太复杂了，以至于编译器要处理很长时间。我们现在不能再忽略这个问题了。

<div id="超越无限 To Infinity And Beyond"/>

## 超越无限 To Infinity And Beyond

如果你尝试过在 Rust 中编写一个递归类型，你或许就直到这个小问题的答案了。

一个类似这样的枚举：

```rs
enum List<A> {
    Cons(A, List<A>),
    Nil,
}
```

rustc 会很敏感的告诉你递归类型 `List<A>` 是无限大的，因此我们需要为这个无线大的数组分配内存。

很多语言中，对于类型系统而言，无限大的数组并不是一个问题。而 Rust 中，我们需要分配内存，或者说是在构建类型是就必须决定它们的大小，因此当类型无限大时，因为这大小也是无限的。

解决方案会有一点不直接。因为我们知道指针的大小，因此无论指针指向哪里，我们的 `List::Cons` 都是固定大小的。为此我们需要让值分配在堆上，Rust 里使用 `Box`：

```rs
enum List<A> {
    Cons(A, Box<List<A>>),
    Nil,
}
```

`Box` 另一个有趣的特性是其包含的类型都是抽象的。这就意味着不再需要复杂的 parser 函数类型，而是通过非常简洁的 `Box<dyn Parser<'a, A>>` 来处理类型。

听起来很棒，那么这样做的坏处呢？我们可能会因为必须遵循该指针而失去一两个指令周期，也可能让编译器失去了一些优化 parser 的机会。

现在让我们用 _boxed_ 来实现 `Parser` 函数：

```rs
struct BoxedParser<'a, Output> {
    parser: Box<dyn Parser<'a, Output> + 'a>,
}

impl<'a, Output> BoxedParser<'a, Output> {
    fn new<P>(parser: P) -> Self
    where
        P: Parser<'a, Output> + 'a,
    {
        BoxedParser {
            parser: Box::new(parser),
        }
    }
}

impl<'a, Output> Parser<'a, Output> for BoxedParser<'a, Output> {
    fn parse(&self, input: &'a str) -> ParseResult<'a, Output> {
        self.parser.parse(input)
    }
}
```

我们创造了新的类型 `BoxedParser` 用于存储 parser 函数。那么正如之前所说的，这就意味着把 parser 放置进堆上，用解引用的方式获取它，这可能会花费我们几个宝贵的纳秒，所以实际上可能需要推迟使用 `box`。只需将一些更常用的组合子放进 `box` 就足够了。

<div id="展示自己的机会 BoxedParser"/>

## 展示自己的机会 BoxedParser

等一下，这么做很可能会带来另外的问题。因为组合子是独立的函数，当我们嵌套的数量比较多时，代码的可读性就会变差。回忆一下 `quoted_string` parser：

```rs
fn quoted_string<'a>() -> impl Parser<'a, String> {
    map(
        right(
            match_literal("\""),
            left(
                zero_or_more(pred(any_char, |c| *c != '"')),
                match_literal("\""),
            ),
        ),
        |chars| chars.into_iter().collect(),
    )
}
```

如果将这些组合子的方法在 parser 上使用而不是使用这样的独立函数，那么可读性就会变得更好。如果我们在 `Parser` trait 上以方法的形式声明我们的组合子呢？

这样做的问题在于我们会丢失返回类型使用 `impl Trait` 的能力，因为 `impl Trait` 不能在 trait 中声明（Rust 2018 版次不行，听说下一个版次就可以了？）。

而现在的 `BoxedParser`，虽然不能声明一个 trait 方法并返回 `impl Parser<'a, A>`，但是完全可以声明一个返回 `BoxedParser<'a, A>` 的 trait。

最棒的地方在于甚至可以声明带有默认实现的 trait，因此我们不需要为每个已经实现了 `Parser` 的类型，再次去实现所有的组合子。

让我们通过拓展 `Parser` trait 来尝试一下 `map` 组合子：

```rs
trait Parser<'a, Output> {
    fn parse(&self, input: &'a str) -> ParseResult<'a, Output>;

    fn map<F, NewOutput>(self, map_fn: F) -> BoxedParser<'a, NewOutput>
    where
        Self: Sized + 'a,
        Output: 'a,
        NewOutput: 'a,
        F: Fn(Output) -> NewOutput + 'a,
    {
        BoxedParser::new(map(self, map_fn))
    }
}
```

一大堆的 `'a`，但是唉，它们都是必须的。幸运的是我们仍然可以复用旧的组合子函数，同时作为额外的好处，我们不仅仅获得了更棒的语法，通过自动的打包它们，我们同样的也去除了暴露的 `impl Trait` 类型。

现在让我们稍微增强一下我们的 `quoted_string` parser：

```rs
fn quoted_string<'a>() -> impl Parser<'a, String> {
    right(
        match_literal("\""),
        left(
            zero_or_more(pred(any_char, |c| *c != '"')),
            match_literal("\""),
        ),
    )
    .map(|chars| chars.into_iter().collect())
}
```

可以很明显的看到在 `right()` 上调用了 `.map()`。 我们也可以以同样的方式处理 `pair`， `left` 和 `right`，但是这三个我认为作为函数保留它们会更好一些，因为它们反映了 `pair` 输出类型的结构。当然了你完全也可以把它们全部加入 trait 中。

另一个候选者是 `pred`。让我们在 `Parser` trait 中添加这个定义。

那么 `quoted_string` 中的 `pred` 调用就可以这么改写：

```rs
zero_or_more(any_char.pred(|c| *c != '"')),
```

可读性变强了，而对于 `zero_or_more` 而言，保留原有写法更好一些，因为它读起来就像谓语那样“零个或多个 `any_char` 应用了以下的 predicate”。当然了如果你愿意的话不管是 `zero_or_more` 还是 `one_or_more` 都可以放进 trait 中。

除了重写 `quoted_string`，让我们把 `single_element` 中的 `map` 也修改一下：

```rs
fn single_element<'a>() -> impl Parser<'a, Element> {
    left(element_start(), match_literal("/>"))
        .map(|(name, attributes)| Element {
            name,
            attributes,
            children: vec![],
        })
}
```

这样我们就打包好了 `map` 和 `pred` 方法 -- 并且我们获取了更好的语法！

<div id="带子元素的情况"/>

## 带子元素的情况

现在让我们编写父子元素的 parser。基本与 `single_element` 一致，除了结尾用的是一个 `>` 而不是 `/>`。它同样遵从 _zero or more_ 子元素以及一个关闭标签，但是我们首先需要解析真实的起始标签：

```rs
fn open_element<'a>() -> impl Parser<'a, Element> {
    left(element_start(), match_literal(">"))
        .map(|(name, attributes)| Element {
            name,
            attributes,
            children: vec![],
        })
}
```

现在那么我们怎么获取子元素呢？它们既可以是单元素也可以是另一个父子元素，并且有 _zero or more_ 个它们。我们又 `zero_or_more` 组合子，但是我们如何使用它呢？有一个还未解决的是多选项（multiple choice）parser：一个既可以处理单元素又可以处理父子元素的 parser。

为了达到这个目标，我们需要一个组合子可以顺序的尝试两种 parser：如果第一个 parser 成功，便使用它并返回其结果；如果失败并不返回错误而是带着输入去尝试第二个 parser，如果还是失败了那么返回错误，这就意味着两个 parser 都失败了。

```rs
fn either<'a, P1, P2, A>(parser1: P1, parser2: P2) ->
    impl Parser<'a, A>
where
    P1: Parser<'a, A>,
    P2: Parser<'a, A>,
{
    move |input| match parser1.parse(input) {
        ok @ Ok(_) => ok,
        Err(_) => parser2.parse(input),
    }
}
```

这便允许我们声明一个 parser `element` 作用于匹配一个单元素或一个父子元素（暂时还是使用 `open_element` 来表示它，我们将在拥有 `element` 后处理子元素）。

```rs
fn element<'a>() -> impl Parser<'a, Element> {
    either(single_element(), open_element())
}
```

现在让我们为关闭标签添加一个 parser。它拥有一个有意思的性质是需要匹配起始标签，这就意味着 parser 需要知道起始标签的名称。这不就正是函数参数的用处吗？

```rs
pub fn close_element<'a>(expected_name: String) -> impl Parser<'a, String> {
    right(match_literal("</"), left(identifier, match_literal(">")))
        .pred(move |name| name == &expected_name)
}
```

现在让我们把它们都组合一下：

```rs
fn parent_element<'a>() -> impl Parser<'a, Element> {
    pair(
        open_element(),
        left(zero_or_more(element()), close_element(…oops)),
    )
}
```

啊我们怎么给 `close_element` 传参呢？我认为还缺少最后一种组合子。

很接近了。一旦我们解决完了最后一个问题使得 `parent_element` 可以正常工作，我们便可以用崭新的 `parent_element` 来替换掉 `element` parser 的 `open_element`，这样我们就有了完整的 XML 解析器了。

还记得之前说过的之后再回到 `and_then` 吗？就是这里！这个 `and_then` 组合子实际上就是我们需要的：它是一个对当前 parser 接受其返回并生产一个新 parser 的函数。它有点像 `pair`，除了不是仅仅接收两个返回值于一个元组中，我们通过一个函数把他们串联起来。我们知道 `and_then` 可以作用于 `Result` 以及 `Option` 上，但是它们仅仅维护一些数据，因为它们并没有做额外的事情。

那么现在我们来实现它：

```rs
pub fn and_then<'a, P, F, A, B, NextP>(parser: P, f: F) ->
    impl Parser<'a, B>
where
    P: Parser<'a, A>,
    NextP: Parser<'a, B>,
    F: Fn(A) -> NextP,
{
    move |input| match parser.parse(input) {
        Ok((next_input, result)) => f(result).parse(next_input),
        Err(err) => Err(err),
    }
}
```

检查类型，这里有大量的类型变量，不过我们知道 `P`，作为输入的 parser，其返回值类型为 `A`。而函数 `F`，`map` 函数是 `A` 至 `B` 的映射，它们最大的区别就是输入 `and_then` 的函数是一个从 `A` 至新 parser `NextP` 的映射，其返回的类型是 `B`。最终返回的类型是 `B`，因此我们可以假设任何从 `NextP` 出来的结果都是最终结果。

代码有一点点复杂：起始时运行 input parser，如果它失败了，那么便结束，如果成功我们就对其结果（类型 `A`）调用 `f` 函数，其输出为 `f(result)` 即一个新的 parser，并带有类型 `B` 的返回值。接着我们再次运行这个 parser 就可以直接返回结果了。如果失败了，那么便在此失败，如果成功了我们便会得到类型 `B` 的结果。

让我们把 `and_then` 也加在 `Parser` trait 上，因为它与 `map` 类似，完全提高了可读性。

```rs
fn and_then<F, NextParser, NewOutput>(self, f: F) ->
    BoxedParser<'a, NewOutput>
where
    Self: Sized + 'a,
    Output: 'a,
    NewOutput: 'a,
    NextParser: Parser<'a, NewOutput> + 'a,
    F: Fn(Output) -> NextParser + 'a,
{
    BoxedParser::new(and_then(self, f))
}
```

那么改写一下 `pair`：

```rs
fn pair<'a, P1, P2, R1, R2>(parser1: P1, parser2: P2) ->
    impl Parser<'a, (R1, R2)>
where
    P1: Parser<'a, R1> + 'a,
    P2: Parser<'a, R2> + 'a,
    R1: 'a + Clone,
    R2: 'a,
{
    parser1.and_then(
        move |result1| parser2
            .map(move |result2| (result1.clone(), result2))
    )
}
```

这看起来很简洁，但是有一个问题：`parser2.map()` 消费了 `parser2` 来创建被包裹的 parser，而该函数是一个 `Fn`，不是 `FnOnce`，所以它不被允许去消费 `parser2`，仅仅只能获取引用。

在 Rust 中我们所能做的就是使用函数来惰性（lazily）生成 right 的 `close_element` parser。

使用 `and_then` 可以构建 right 版本的 `close_element`。

```rs
pub fn parent_element<'a>() -> impl Parser<'a, Element> {
    open_element().and_then(|el| {
        left(zero_or_more(element()), close_element(el.name.clone()))
            .map(move |children| {
                let mut el = el.clone();
                el.children = children;
                el
            })
    })
}
```

现在看起来变得更加复杂了，因为 `and_then` 必须跟在 `open_element()` 之后，也就是我们找到元素名字的地方并使其进入 `close_element`。这就意味着在 `open_element` 之后的所有 parser 必须在 `and_then` 闭包之中进行构建。此外因为闭包现在是 `open_element` 的 `Element` 结果的唯一接收者，我们返回的 parser 也必须将信息一直向前传递。

在里面的闭包中，也就是我们 `map` 生成 parser 的闭包，带有一个从外部闭包 `Element` 的引用（`el`）。我们必须 `clone()` 它，因为我们是在一个 `Fn` 内部因此只有一个它的引用。我们拿着内部 parser（`Vec<Element>` 子元素）的结果并将它们添加至拷贝的 `Element` 中，作为我们最终的返回。

现在我们需要做的是返回 `element` parser 并确保我们把 `open_element` 替换成 `parent_element`，这样它就可以解析整个元素结构了！

<div id="是你讲那个 M 词还是由我来讲呢"/>

## 是你讲那个 M 词还是由我来讲呢？

还记得我们谈过的 `map` 模式在 Haskell 中是被称之为一个函子 functor 吗？

`and_then` 模式是另一个在 Rust 中常见的模式，通常来说与 `map` 伴生。在 `Iterator` 上它被称为 `flat_map`，而其实它与 `and_then` 是一样的。

这个美丽的单词就是“单子（monad）”。如果你拥有一个 `Thing<A>`，那么你的一个 `and_then` 函数就允许你传递一个从 `A` 转换至 `Thing<B>` 的函数，因此你就拥有了一个新的 `Thing<B>`，这便是单子 monad。

这个函数可能会被立马调用，正如当你有一个 `Option<A>`，我们已经知道了它是一个 `Some(A)` 或是一个 `None`，因此直接应用此函数的话，如果是一个 `Some(A)`，那么返回的便是 `Some(B)`。

这个函数也可以被惰性的调用。例如如果你有一个 `Future<A>`，它在等待结果，`and_then` 不是立刻调用函数并创建 `Future<B>`，而是创建一个 `Future<B>` 其中包含了 `Future<A>` 以及等待 `Future<A>` 结束的函数。

尽管拥有函子 functor，Rust 的类型系统展示还没有能力来表达单子 monad，所以我们只需要知道这个模式被称为 monad 即可。

<div id="空格 Redux"/>

## 空格 Redux

最后一件事。我们需要一个 parser 能够解析一些 XML，但是在处理空格方面还是不太让人满意。随机的空格是被允许在标签之间，这样就可以随意的在标签插入分行。

```rs
fn whitespace_wrap<'a, P, A>(parser: P) -> impl Parser<'a, A>
where
    P: Parser<'a, A>,
{
    right(space0(), left(parser, space0()))
}
```

如果我们包裹了 `element`，它会忽略所有在 `element` 周围的空格，这就意味着我们可以随意的添加任意行数与缩进了。

```rs
fn element<'a>() -> impl Parser<'a, Element> {
    whitespace_wrap(either(single_element(), parent_element()))
}
```

<div id="终于完成了"/>

## 终于完成了

我认为我们做到了！最后再写一个综合测试来庆祝一下。

```rs
#[test]
fn xml_parser() {
    let doc = r#"
        <top label="Top">
            <semi-bottom label="Bottom"/>
            <middle>
                <bottom label="Another bottom"/>
            </middle>
        </top>"#;
    let parsed_doc = Element {
        name: "top".to_string(),
        attributes: vec![("label".to_string(), "Top".to_string())],
        children: vec![
            Element {
                name: "semi-bottom".to_string(),
                attributes: vec![
                    ("label".to_string(), "Bottom".to_string())
                ],
                children: vec![],
            },
            Element {
                name: "middle".to_string(),
                attributes: vec![],
                children: vec![Element {
                    name: "bottom".to_string(),
                    attributes: vec![
                        ("label".to_string(), "Another bottom".to_string())
                    ],
                    children: vec![],
                }],
            },
        ],
    };
    assert_eq!(Ok(("", parsed_doc)), element().parse(doc));
}
```

以及一个错误匹配了闭合标记的错误测试：

```rs
#[test]
fn mismatched_closing_tag() {
    let doc = r#"
        <top>
            <bottom/>
        </middle>"#;
    assert_eq!(Err("</middle>"), element().parse(doc));
}
```

好消息是它返回了不匹配的闭合标签作为错误结果。坏消息是它没有真正的提到问题是因为不匹配的闭合标签，仅仅只有错误的地点。不过比什么都没有好，平心而论即使有了错误信息，它还是糟糕的。转换它成为一个能提供优秀信息的错误可能需要另一篇文章来解决了。

还是让我们聚焦好消息：我们通过 parser 组合子的方式编写一个解析器！我们知道了一个 parser 既可以构成函子又可以构成单子，所以现在的你就可以用令人畏惧的范畴论知识在聚会上给人留下深刻印象了！

最重要的是，我们现在知道解析器组合子是如何从头开始工作的。 现在没有人能阻止我们！

<div id="额外的资源"/>

## 额外的资源

[nom](https://github.com/Geal/nom)

[combine](https://github.com/Marwes/combine)

[Programming in Haskell](http://www.cs.nott.ac.uk/~pszgmh/pih.html)
