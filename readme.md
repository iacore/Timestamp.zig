Parsing `2000-01-01T00:00:00.000Z` into UNIX timestamp. Reverse conversion included (courtesy of [nektro/zig-time](https://github.com/nektro/zig-time/)).

## License

WTFPL. Do what you want.

## Usage

First, download this repo with `git subtree`, `git submodule`, or just as a zip file and extract it to `libtimestamp/`.

In `build.zig`:

```zig
	const dep_Timestamp = b.anonymousDependency("libtimestamp", @import("libtimestamp/build.zig"), .{});

    exe.addModule("Timestamp", dep_Timestamp.module("Timestamp"));
```
