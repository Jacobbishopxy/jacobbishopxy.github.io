+++
title = "Latex setup"
description = "MacOS + VS Code"
date = 2022-12-03
updated = 2022-12-04

[taxonomies]
categories = ["Post"]
tags = ["Latex"]
+++

1. [MacTeX](https://www.tug.org/mactex/): choose smaller download, or by Homebrew:

   ```sh
   brew install mactex-no-gui
   ```

   or

   ```sh
   brew install basictex
   ```

1. Update `tlmgr` and add to PATH:

   ```sh
   sudo tlmgr update --self
   sudo tlmgr path add
   ```

1. Install `tlmgr` plugins, check [ctan](https://ctan.org/) for more:

   ```sh
   sudo tlmgr install latexmk
   sudo tlmgr install ctex
   ```

   note `ctex` supports Chinese words.

1. Install `latexindent`:

   ```sh
   brew install latexindent
   ```

1. Install VS Code plugin: [LaTex-Workshop](https://github.com/James-Yu/LaTeX-Workshop).

1. Add following configs into VS Code's `settings.json`:

   ```json
   "latex-workshop.latex.outDir": "./out/",
   "latex-workshop.latex.recipes": [
      {
         "name": "xelatex",
         "tools": ["xelatex"]
      },
      {
         "name": "latexmk",
         "tools": ["latexmk"]
      }
   ],
   "latex-workshop.latex.tools": [
      {
         "name": "xelatex",
         "command": "xelatex",
         "args": [
            "-synctex=1",
            "-interaction=nonstopmode",
            "-file-line-error",
            "-output-directory=%OUTDIR%",
            "%DOC%"
         ]
      },
      {
         "name": "latexmk",
         "command": "latexmk",
         "args": [
            "-synctex=1",
            "-interaction=nonstopmode",
            "-file-line-error",
            "-pdf",
            "-outdir=%OUTDIR%",
            "%DOC%"
         ],
      }
   ]
   ```

   Note: we can choose a compiler to compile our files by `LaTex Workshop: Build with recipe`
