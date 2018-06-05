Dependency Tool for D
=====================

[![Build Status](https://travis-ci.com/funkwerk/depend.svg?branch=master)](https://travis-ci.com/funkwerk/depend)

This tool checks actual import dependencies against a UML model of target dependencies.

Usage
-----

Run [dmd](http://dlang.org/dmd-linux.html) with the switch `--deps`
to extract the actual dependencies. For example:

    dmd -deps=dependencies src/depend.d -o-

Use the _depend_ tool together with the [Graphviz](http://www.graphviz.org) programs
for a visualization of the module dependencies:

    src/depend.d --dot dependencies | dot -Tsvg -odependencies.svg

For best results, remove the transitive dependencies:

    src/depend.d --dot dependencies | tred | dot -Tsvg -odependencies.svg

Consider switching to package dependencies instead of module dependencies:

    src/depend.d --packages --dot dependencies | tred | dot -Tsvg -odependencies.svg

Or filter dependencies of source files matching a regular expression:

    src/depend.d --filter 'src|test' --dot dependencies | tred | dot -Tsvg -odependencies.svg

Then, specify the target dependencies as a [PlantUML](http://plantuml.sourceforge.net) model.
For example, create a text file _model.uml_:

    package model {}
    package view {}
    package controller {}

    controller ..> view
    controller ..> model
    view .> model

Finally, use the _depend_ tool for checking actual dependencies against the target dependencies:

    src/depend.d --target model.uml dependencies

The tool complains about violations:

    error: unintended dependency model -> controller
