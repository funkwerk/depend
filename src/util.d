module util;

version(unittest) import dshould;
import std.algorithm;
import std.range;
import std.string;

string packages(string fullyQualifiedName)
{
    return fullyQualifiedName.split('.')
        .dropBackOne
        .join('.');
}

@("split packages from a fully-qualified module name")
unittest
{
    packages("bar.baz.foo").should.equal("bar.baz");
    packages("foo").should.be.empty;
}

bool fqnStartsWith(string haystack, string needle)
{
    return haystack.splitter(".").startsWith(needle.splitter("."));
}

@("fully-qualified module name starts with other name")
unittest
{
    "foo".fqnStartsWith("foo").should.be(true);
    "foo.bar.baz".fqnStartsWith("foo.bar").should.be(true);
    "foo".fqnStartsWith("fo").should.be(false);
    "foo.bar.baz".fqnStartsWith("foo.ba").should.be(false);
}

/**
 * This function takes two modules and returns the crossed package boundaries.
 *
 * Imagine a diagram of modules, where each module is recursively contained in
 * successive packages. Now imagine an arrow drawn from the first to the second
 * module. There may be some package boundaries that this arrow will necessarily have
 * to cross to get to its destination. This function returns those boundaries.
 */
const(string)[] crossedPackageBoundaries(string from, string to)
{
    const fromPackages = from.successiveSplitPrefixes(".");
    const toPackages = to.successiveSplitPrefixes(".");
    const sharedPackages = fromPackages.commonPrefix(toPackages);
    const numSharedPackages = count(sharedPackages);
    const lastCommonPackage = sharedPackages.back; // at least ""
    const fromUniquePackages = fromPackages.drop(numSharedPackages);
    const toUniquePackages = toPackages.drop(numSharedPackages);
    const traversalPath = chain(fromUniquePackages.retro, lastCommonPackage.only, toUniquePackages)
        .dropOne.dropBackOne;

    return traversalPath.filter!(a => !a.empty).array;
}

@("import crosses package boundaries")
unittest
{
    crossedPackageBoundaries("a", "b").should.be.empty;
    crossedPackageBoundaries("a", "b.y").should.be(["b"]);
    crossedPackageBoundaries("a.x", "b").should.be(["a"]);
    crossedPackageBoundaries("a.x", "b.y").should.be(["a", "b"]);
    crossedPackageBoundaries("a.x", "a").should.be.empty;
    crossedPackageBoundaries("a.x.y", "a").should.be(["a.x"]);
}

private string[] successiveSplitPrefixes(string haystack, string needle)
{
    auto parts = haystack.split(needle);

    return (parts.length + 1).iota.map!(i => parts.take(i).join(needle)).array;
}

@("generate successive prefixes of a string split at a marker")
unittest
{
    "".successiveSplitPrefixes(".").should.be([""]);
    "a".successiveSplitPrefixes(".").should.be(["", "a"]);
    "a.b".successiveSplitPrefixes(".").should.be(["", "a", "a.b"]);
    "a.b.c".successiveSplitPrefixes(".").should.be(["", "a", "a.b", "a.b.c"]);
}
