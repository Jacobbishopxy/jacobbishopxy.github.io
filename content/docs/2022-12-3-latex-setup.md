+++
title = "Latex setup"
description = "MacOS/Ubuntu + VS Code"
date = 2022-12-03
updated = 2022-12-04

[taxonomies]
categories = ["Post"]
tags = ["Latex"]
+++

## MacOS

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

## Ubuntu

1. [TexLive](https://www.tug.org/texlive/)

   ```sh
   sudo apt-get install texlive-full
   ```

   or

   > cd /tmp # working directory of your choice
   > wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz # or curl instead of wget
   > zcat install-tl-unx.tar.gz | tar xf -
   > cd install-tl-*
   > perl ./install-tl --no-interaction # as root or with writable destination
   > Finally, prepend /usr/local/texlive/YYYY/bin/PLATFORM to your PATH, e.g., /usr/local/texlive/2022/bin/x86_64-linux

## Vs Code

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
