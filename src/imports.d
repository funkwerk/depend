module imports;

import std.algorithm;
import std.array;
import std.path;
import std.range;
import std.regex;
import std.typecons;

version (unittest) import unit_threaded;

public auto scanImports(const string[] args)
{
    const lookup = Lookup(args);

    return lookup.sourceFiles
        .map!(sourceFile => extractImports(sourceFile, lookup))
        .joiner;
}

public auto extractImports(const string file, Lookup lookup)
{
    import std.file : readText;

    alias Module = Tuple!(string, "name", string, "path");
    alias Dependency = Tuple!(Module, "client", Module, "supplier");

    auto toModule(string name)
    {
        return Module(name, lookup.path(name));
    }

    const source = file.readText;
    const moduleName = declaredModule(source);

    return importedModules(source)
        .map!(name => Dependency(Module(moduleName, file), toModule(name)))
        .array;
}

string declaredModule(R)(R input)
{
    import std.string : join, strip;

    enum fullyQualifiedName = `(?P<fullyQualifiedName>\w+(\s*\.\s*\w+)*)`;
    enum pattern = regex(`\bmodule\s+` ~ fullyQualifiedName);

    // TODO: skip comments, string literals
    if (auto captures = input.matchFirst(pattern))
    {
        return captures["fullyQualifiedName"].splitter('.').map!strip.join('.');
    }
    return null;  // FIXME: fall back to basename?
}

@("scan module declaration")
unittest
{
    declaredModule("module bar.baz;").should.be == "bar.baz";
    declaredModule("module bar . baz;").should.be == "bar.baz";
}

auto importedModules(R)(R input)
{
    import std.string : join, strip;

    enum fullyQualifiedName = `(?P<fullyQualifiedName>\w+(\s*\.\s*\w+)*)`;
    enum pattern = regex(`\bimport\s+(\w+\s*=\s*)?` ~ fullyQualifiedName);

    // TODO: skip comments, string literals
    return input.matchAll(pattern)
        .map!(a => a["fullyQualifiedName"].splitter('.').map!strip.join('.'));
}

@("scan import declarations")
unittest
{
    importedModules("import bar.baz;").shouldEqual(["bar.baz"]);
    importedModules("import foo = bar.baz;").shouldEqual(["bar.baz"]);
    importedModules("import bar . baz;").shouldEqual(["bar.baz"]);
}

struct Lookup
{
    const string[] sourceFiles;

    const string[] importPaths;

    this(const string[] args)
    {
        import std.string : chompPrefix;

        sourceFiles = args
            .filter!(arg => arg.extension == ".d")
            .array;
        importPaths = args
            .filter!(arg => arg.startsWith("-I"))
            .map!(arg => arg.chompPrefix("-I"))
            .array;
    }

    string path(string fullyQualifiedName)
    {
        const path = fullyQualifiedName.splitter(".").buildPath.setExtension(".d");
        const packagePath = chain(fullyQualifiedName.splitter("."), only("package")).buildPath.setExtension(".d");

        return chain(
                match(path),
                match(packagePath),
                only(path),
        ).front;
    }

    auto match(string partialPath)
    {
        import std.file : exists;

        return chain(
                sourceFiles.filter!(path => path.pathSplitter.endsWith(partialPath.pathSplitter)),
                importPaths.map!(path => buildPath(path, partialPath)).filter!(path => path.exists),
        );
    }
}
