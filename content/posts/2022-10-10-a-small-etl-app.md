+++
title = "A Small ETL App"
description = "Yet another Fabrix"
date = 2022-10-10
updated = 2022-10-11

draft = true

[taxonomies]
categories = ["Post"]
tags = ["Rust"]

[extra]
toc = true
+++

## Intro

There comes an impulse when I was reading `arrow2` documentation: instead of using ODBC, which is partially supported by `arrow2` but not controllable (sometimes even not compilable when using MacOS), shall I write a connector for reading and writing databases? And this time, without using runtime query data's schema from a database as what I did in [Fabrix](https://github.com/Jacobbishopxy/fabrix), I decide to use static schema which in other words compile-time schemed data structure. As a lib, this benefits user who has already known data schema, and can be quickly used in production without writing SQL statements.

Then what this lib crate can do and its requirement:

- An application who supports different types of data sources' read and write
- Data schema is already known before compile

In order to achieve this goal I've made a list of challenges (todo) as well:

- Include a SQL toolkit which supports synchronies and different types of database

- Custom error supports for my lib crate

- Rust native typed array and `arrow` array's conversions

- A new type of `arrow` chuck, who stores different type of array, encapsulates methods who solve different sources of data's read and write

- Rust procedure macros to generate compile-time schema's functions

Alright, let's speed up and launch our tutorial, firmly.

## Determine structure

WIP
