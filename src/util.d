module util;

import std.string;

string packages(string fullyQualifiedName)
{
    import std.range : dropBackOne;

    return fullyQualifiedName.split('.')
        .dropBackOne
        .join('.');
}

version (unittest) import dshould;

@("split packages from a fully-qualified module name")
unittest
{
    packages("bar.baz.foo").should.equal("bar.baz");
    packages("foo").should.be.empty;
}

bool fqnStartsWith(string haystack, string needle)
{
    import std.algorithm : splitter;

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
