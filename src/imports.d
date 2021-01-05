module imports;

import model;
import std.algorithm;
import std.array;
import std.range;
import std.typecons;

version (unittest) import unit_threaded;

auto mutualDependencies(const string[] args)
{
    string[][string] importedModules;

    foreach (arg; args)
        with (readImports(arg))
            importedModules[client] ~= suppliers;
    return importedModules.byKeyValue
        .map!(pair => pair.value.map!(supplier => Dependency(pair.key, supplier)))
        .joiner
        .filter!(dependency => dependency.supplier.toString in importedModules);
}

auto readImports(string file)
{
    import std.file : readText;
    import std.path : baseName, stripExtension;

    const input = file.readText;
    auto captures = moduleDeclaration(input);
    const client = captures
        ? captures["fullyQualifiedName"].toFullyQualifiedName
        : file.baseName.stripExtension;
    const suppliers = importDeclarations(input)
        .map!(captures => captures["fullyQualifiedName"].toFullyQualifiedName)
        .array;

    return tuple!("client", "suppliers")(client, suppliers);
}

auto moduleDeclaration(R)(R input)
{
    import std.regex : matchFirst, regex;

    // TODO: skip comments, string literals
    enum pattern = regex(`\bmodule\s+` ~ fullyQualifiedName ~ `\s*;`);

    return input.matchFirst(pattern);
}

@("match module declaration")
unittest
{
    auto captures = moduleDeclaration("module bar.baz;");

    captures.shouldBeTrue;
    captures["fullyQualifiedName"].should.be == "bar.baz";
}

@("match module declaration with white space")
unittest
{
    auto captures = moduleDeclaration("module bar . baz\n;");

    captures.shouldBeTrue;
    captures["fullyQualifiedName"].should.be == "bar . baz";
}

auto importDeclarations(R)(R input)
{
    import std.regex : matchAll, regex;

    // TODO: skip comments, string literals
    enum pattern = regex(`\bimport\s+(\w+\s*=\s*)?` ~ fullyQualifiedName ~ `[^;]*;`);

    return input.matchAll(pattern);
}

@("match import declaration")
unittest
{
    auto match = importDeclarations("import bar.baz;");

    match.shouldBeTrue;
    match.map!`a["fullyQualifiedName"]`.shouldEqual(["bar.baz"]);
}

@("match import declaration with white space")
unittest
{
    auto match = importDeclarations("import bar . baz\n;");

    match.shouldBeTrue;
    match.map!`a["fullyQualifiedName"]`.shouldEqual(["bar . baz"]);
}

@("match renamed import")
unittest
{
    auto match = importDeclarations("import foo = bar.baz;");

    match.shouldBeTrue;
    match.map!`a["fullyQualifiedName"]`.shouldEqual(["bar.baz"]);
}

enum fullyQualifiedName = `(?P<fullyQualifiedName>\w+(\s*\.\s*\w+)*)`;

string toFullyQualifiedName(string text)
{
    import std.string : join, strip;

    return text.splitter('.').map!strip.join('.');
}

@("convert text to fully-qualified name")
unittest
{
    "bar . baz".toFullyQualifiedName.should.be == "bar.baz";
}
