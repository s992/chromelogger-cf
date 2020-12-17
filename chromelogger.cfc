component {

	public chromelogger function init( autoWriteHeader = true, convertObjects = true ) {

		variables.version = "0.1";
		variables.headerName = "X-ChromeLogger-Data";
		variables.path = getMetaData( this ).path;
		variables.autoWriteHeader = arguments.autoWriteHeader;
		variables.convertObjects = arguments.convertObjects;
		variables.backtraces = [];
		variables.processed = [];
		variables.logObject = {
			"version" = variables.version
			, "columns" = [ "log", "backtrace", "type" ]
			, "rows" = []
		};

		return this;

	}

	public void function log() {

		var args = argsToArray( args = arguments );
		arrayPrepend( args, "log" );
		_log( args );

	}

	public void function warn() {

		var args = argsToArray( args = arguments );
		arrayPrepend( args, "warn" );
		_log( args );

	}

	public void function error() {

		var args = argsToArray( args = arguments );
		arrayPrepend( args, "error" );
		_log( args );

	}

	public void function group() {

		var args = argsToArray( args = arguments );
		arrayPrepend( args, "group" );
		_log( args );

	}

	public void function groupCollapsed() {

		var args = argsToArray( args = arguments );
		arrayPrepend( args, "groupCollapsed" );
		_log( args );

	}

	public void function groupEnd() {

		var args = argsToArray( args = arguments );
		arrayPrepend( args, "groupEnd" );
		_log( args );

	}

	private void function _log( required array args ) {

		// chromelogger treats "log" and "" the same, so save a few bytes in the header by passing
		// an empty string if the severity is "log."
		var severity = arguments.args[ 1 ] == "log" ? "" : arguments.args[ 1 ];
		var backtrace = getBacktrace();
		var convertedArgs = [];

		// pop off the severity now that we have it in a var.
		arrayDeleteAt( arguments.args, 1 );

		// no need to continue if we're not logging anything, unless we're ending a group.
		if( !arrayLen( arguments.args ) && severity != "groupEnd" ) {
			return;
		}

		if( arrayFindNoCase( variables.backtraces, backtrace ) ) {

			// kill the backtrace if we've already processed a log with the same backtrace
			// i.e. logging within a loop
			backtrace = "";

		} else {

			// otherwise, stick it in our saved backtraces so we can kill the next one.
			arrayAppend( variables.backtraces, backtrace );

		}

		for( var arg in args ) {

			arrayAppend( convertedArgs, convert( arg ) );

		}

		addRow( convertedArgs, backtrace, severity );

	}

	private void function addRow( required array logs, required string backtrace, required string severity ) {

		// backtrace is not useful in grouped logging, so kill it.
		if( listFindNoCase( "group,groupEnd,groupCollapsed", arguments.severity ) ) {
			arguments.backtrace = "";
		}

		arrayAppend( getLogObject().rows, [
			arguments.logs
			, arguments.backtrace == "" ? javaCast( "null", 0 ) : arguments.backtrace
			, arguments.severity
		]);

		if( variables.autoWriteHeader ) {
			writeHeader();
		}

	}

	public void function writeHeader() {

		if( arrayLen( getLogObject().rows ) ) {
			getPageContext().getResponse().setHeader( variables.headerName, encode( getLogObject() ) );
		}

	}

	private string function encode( required struct data ) {

		return toBase64( serializeJSON( arguments.data ) );

	}

	// this is mostly here for unit testing purposes.
	public struct function getLogObject() {

		return variables.logObject;

	}

	public void function reset() {

		getLogObject().rows = [];

	}

	/**
	* Recurses over an object and its properties to create a struct representation of the object. This is
	* more useful than just calling serializeJSON on an object (especially when used with ORM entities, where
	* serializeJSON is completely broken). There's plenty of hackery here, so beware.
	*/
	private any function convert( required any object ) {

		if( !variables.convertObjects ) {
			return arguments.object;
		}

		var md = getMetaData( arguments.object );

		// was getting some weirdness where methods were being added to the log if they were part of
		// hibernate entities, which in turn causes a stack overflow when we try to serialize. discarding
		// methods from the start fixes that.
		if( isMethod( arguments.object ) ) {
			return md.name;
		}

		// no need to continue if we aren't working with an object or if the passed object
		// is an exception. exceptions return true in an isObject call, but they have a different
		// underlying base class and don't work the same as other CFCs. better to just not screw
		// with the exception and log it as is.
		if( !isObject( arguments.object ) || isException( arguments.object ) ) {
			return arguments.object;
		}

		var obj = {};
		var props = {};
		var prop = "";
		var propval = "";
		var comparison = {};
		var isCollection = false;
		var isStructCollection = false;

		// save this object so that we don't get into an infinite loop if objects are referencing each other.
		saveProcessedObject( arguments.object );

		// ___class_name is a special keyword for chromelogger that allows it to print the object name all fancy-like
		obj[ "___class_name" ] = md.name;

		// rather than calling evaluate() on getters, we're going to inject a getter method into the object and
		// use that while looping the properties. i'm not sure which is better, but i'm not really happy with either.
		arguments.object[ "__chromecf_injected_getter" ] = __chromecf_injected_getter;

		do {

			props = structKeyExists( md, "properties" ) ? md.properties : [];

			for( var i = 1; i <= arrayLen( props ); i++ ) {

				prop = props[ i ];

				if( structKeyExists( arguments.object, "get" & prop.name ) ) {

					propval = arguments.object.__chromecf_injected_getter( prop.name );
					propval = isNull( propval ) ? "" : propval;
					isCollection = ( isStruct( propval ) && !isObject( propval ) ) || isArray( propval );

					if( isCollection ) {

						obj[ prop.name ] = [];
						isStructCollection = isStruct( propval ) && !isObject( propval );

						for( var item in propval ) {

							item = isStructCollection ? propval[ item ] : item;

							if( isRecursion( arguments.object, item ) ) {

								item = getRecursionString( item );

							}

							arrayAppend( obj[ prop.name ], convert( item ) );

						}

					} else {

						if( isRecursion( arguments.object, propval ) ) {

							propval = getRecursionString( propval );

						}

						obj[ prop.name ] = convert( propval );

					}

				}

			}

			if( structKeyExists( md, "extends" ) ) {
				md = md.extends;
			}

		} while( structKeyExists( md, "extends" ) );

		// let's get rid of our injected method before someone starts asking questions..
		structDelete( arguments.object, "__chromecf_injected_getter" );

		return obj;

	}

	private void function saveProcessedObject( required any object ) {

		arrayAppend( variables.processed, arguments.object );

	}

	private boolean function isRecursion( required any object1, required any object2 ) {

		var comparison = {
			obj1 = { obj = arguments.object1 }
			, obj2 = { obj = arguments.object2}
		};

		return comparison.obj1.equals( comparison.obj2 ) || arrayFind( variables.processed, arguments.object2 );

	}

	private string function getRecursionString( required any object ) {

		return "recursion - parent object [ #getMetaData( arguments.object ).name# ]";

	}

	private array function argsToArray( required struct args ) {

		var argsLength = structCount( arguments.args );
		var arr = [];

		for( var i = 1; i <= argsLength; i++ ) {

			arrayAppend( arr, arguments.args[ i ] );

		}

		return arr;

	}

	private string function getBacktrace() {
		var backtrace = "";

		// try to get the info via callStackGet()
		try {
			var callstack = callStackGet();
			var i = 1;
			while (i <= arrayLen(callstack) && callstack[i].template == variables.path) {
				i++;
			}
			backtrace = callstack[i].template & " : " & callstack[i].lineNumber;
		} catch (any) {
			var stacktrace = createObject( "java", "java.lang.Thread" ).currentThread().getStackTrace();
			var tracelength = arrayLen( stacktrace );
			var item = "";

			for( var i = 1; i <= tracelength; i++ ) {

				item = stacktrace[ i ];

				// grab the first item in the stack trace that is a cfc/cfm file and is not the chromelogger cfc
				if( reFindNoCase( "\.cf[cm]$", item.getFileName() ) && item.getFileName() != variables.path ) {

					backtrace = item.getFileName() & " : " & item.getLineNumber();
					break;

				}

			}
		}

		return backtrace;

	}

	private boolean function isException( required any object ) {

		// all exceptions (i think?) ultimately extend java.lang.Throwable
		return isInstanceOf( arguments.object, "java.lang.Throwable" );

	}

	private boolean function isMethod( required any object ) {

		// query metadata is different from every other data type because coldfusion is awesome, or something like that.
		// a query certainly isn't a method, so we don't need to jump through hoops with the MD to figure that out.
		return !isQuery( arguments.object ) && structKeyExists( getMetaData( arguments.object ), "parameters" );

	}

	/**
	* This method is injected into any logged objects in lieu of using evaluate(). As noted in
	* the convert() method's comments, I'm not sure how I feel about this.
	*/
	private any function __chromecf_injected_getter( required string property ) {

		var getter = this[ "get" & arguments.property ];
		return getter();

	}

}
