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
   brew install cask mactex-no-gui
   ```

   or

   ```sh
   brew install cask basictex
   ```

1. Install `latexmk` and add to PATH:

   ```sh
   sudo tlmgr install latexmk
   sudo tlmgr path add
   ```

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
         "name": "latexmk 🔃",
         "tools": ["latexmk"]
      }
   ],
   "latex-workshop.latex.tools": [
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
         "env": {}
      }
   ]
   ```
