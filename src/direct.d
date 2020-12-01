module direct;

import std.algorithm;
import std.array;
import std.exception;
import std.file;
import std.format;
import std.path;
import std.regex;
import std.typecons;

public auto extractImports(const string file, const string[] sources, const string[] includes)
{
    alias Module = Tuple!(string, "name", string, "path");
    alias Dependency = Tuple!(Module, "client", Module, "supplier");

    const source = file.readText;
    auto moduleStatement = source.matchFirst(ctRegex!(`(^|[^\w])module\s*([\w\.]+);`));

    enforce(!moduleStatement.empty, format!"%s: cannot find module statement"(file));

    const moduleName = moduleStatement[2];

    auto toModule(string name)
    {
        return Module(name, findModulePath(name, sources, includes));
    }

    // TODO filter out comments
    auto importStatements = source.matchAll(ctRegex!(`[^\w]import\s+([\w\.]+)`));

    return importStatements.map!(import_ => Dependency(Module(moduleName, file), toModule(import_[1]))).array;
}

private string findModulePath(const string name, const string[] sources, const string[] includes)
{
    const file = name.split(".").buildPath ~ ".d";

    if (const path = findFilePath(file, sources, includes))
    {
        return path;
    }

    const packageFile = (name.split(".") ~ "package.d").buildPath;

    if (const path = findFilePath(packageFile, sources, includes))
    {
        return path;
    }
    // fall back to relative path
    return file;
}

private string findFilePath(const string partialPath, const string[] sources, const string[] includes)
{
    auto matchingSource = sources.find!(a => a.pathSplitter.endsWith(partialPath.pathSplitter));

    if (!matchingSource.empty)
    {
        return matchingSource.front;
    }

    auto matchingIncludePath = includes.find!(a => a.chainPath(partialPath).exists);

    if (!matchingIncludePath.empty)
    {
        return matchingIncludePath.front;
    }

    return null;
}
