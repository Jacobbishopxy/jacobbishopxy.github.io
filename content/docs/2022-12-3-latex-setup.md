+++
title = "Latex setup"
description = "MacOS + VsCode"
date = 2022-12-03
updated = 2022-12-03

[taxonomies]
categories = ["Post"]
tags = ["latex"]
+++

1. [MacTeX](https://www.tug.org/mactex/): choose smaller download

1. Install `latexmk` and add to PATH:

   ```sh
   sudo tlmgr install latexmk
   sudo tlmgr path add
   ```

1. Install `latexindent`:

   ```sh
   brew install latexindent
   ```
