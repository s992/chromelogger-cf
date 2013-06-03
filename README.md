Overview
===============

ColdFusion component for logging variables to Google Chrome console using the Chrome Logger extension, found at [http://chromelogger.com](http://chromelogger.com).

This component is only intended to be used in a development environment.

Requirements
===============

CF 9 or 10. Untested in Railo/Open BD.

Installation
===============

1. Install the [Chrome Logger](https://chrome.google.com/webstore/detail/chrome-logger/noaneddfkdjfnfdakjjmocngnfkfehhd) extension.
2. Click the Chrome Logger icon to enable logging.
3. Stick `chromelogger.cfc` somewhere that it can be instantiated.
4. Instantiate `chromelogger.cfc`.
5. Start logging!

	```cfml
	<cfscript>
	console = new chromelogger.chromelogger();
	console.log( "Logging some data!" );
	console.error( "This is an error.." );
	console.log({ "It logs more" = "than just strings." });
	</cfscript>
	```

Usage
===============

**Note**: Please disregard `<cfscript/>` tags in the following code examples; They're only there because GitHub doesn't like to syntax highlight cfscript without them.

Options
---------------

`chromelogger-cf` can be instantiated with a few different options:

```cfml
<cfscript>
console = new chromelogger.chromelogger( autoWriteHeader = true, convertObjects = true );
</cfscript>
```

1. `autoWriteHeader` - If true, automatically sets the header at the end of each `.log()` call. ColdFusion 9 users should set this to false due to a bug in CF9 that prevents `setHeader` from overwriting a header with the same name. If true, the header will have to be set manually at the end of the request - see [the example below](https://github.com/s992/chromelogger-cf#manually-setting-header).
2. `convertObjects` - Because `serializeJSON()` is mediocre at best for serializing objects, the `convert()` method is utilized to create a struct representation of a given object. Some users may prefer the default behavior of `serializeJSON()`, so `chromelogger` can be instantiated with `convertObjects = false` to prevent the conversion.

Manually Setting Header
---------------

For CF9, the `X-ChromeLogger-Data` header must be set manually. My preferred method of doing so is via `onRequestEnd`.

```cfml
<cfscript>
component {

	function onRequestStart( autoWriteHeader = false ) {

		request.chromelogger = new chromelogger.chromelogger();

	}

	// ...

	function onRequestEnd() {

		request.chromelogger.writeHeader();

	}

}
</cfscript>
```

Using chromelogger as a Singleton
---------------

`chromelogger` should generally be treated as a singleton in the context of the request, but as a transient in the context of the application. The logged items are stored in the `variables` scope of the component, so it's important that this data is flushed out at the end of each request or the logged data will eventually become too large for Chrome to handle in a single header. If `chromelogger` must be used as an application singleton, an extra step must be taken to reset the data after each request.

```cfml
<cfscript>
component {

	function onApplicationStart() {

		application.chromelogger = new chromelogger.chromelogger();

	}

	// ...

	function onRequestEnd() {

		application.chromelogger.reset();

	}

}
</cfscript>
```

API
---------------

The following methods are available from `chromelogger.cfc`:

### chromelogger.log()
Logs all passed arguments to the Chrome console with a severity of "log."

### chromelogger.warn()
Logs all passed arguments to the Chrome console with a severity of "warn."

### chromelogger.error()
Logs all passed arguments to the Chrome console with a severity of "error."

### chromelogger.group( groupLabel )
Begins a group log. Should be followed by calls to `log()`, `warn()`, and/or `error()`, and then closed via `groupEnd()`.

### chromelogger.groupCollapsed( groupLabel )
Begins a collapsed group log. Should be followed by calls to `log()`, `warn()`, and/or `error()`, and then closed via `groupEnd()`.

### chromelogger.groupEnd()
Ends a group or collapsed group.

### chromelogger.writeHeader()
Sets the `X-ChromeLogger-Data` header.

### chromelogger.reset()
Removes all data that has been logged.


Thanks
===============

Thanks to the following repos for inspiration:
 * [chromephp](https://github.com/ccampbell/chromephp)
 * [chromelogger-python](https://github.com/ccampbell/chromelogger-python)
