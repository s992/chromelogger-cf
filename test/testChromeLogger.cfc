component extends="mxunit.framework.TestCase" {

	public void function setUp() {

		variables.cl = new chromelogger.chromelogger( autoWriteHeader = false );

		// sample log object from the chrome logger tech spec
		variables.sampleLogObject = {
			"version" = "0.1"
			, "columns" = [ "log", "backtrace", "type" ]
			, "rows" = [
				[
					[{
						"___class_name" = "User"
						, "name" = "Craig"
						, "occupation" = "NFL Player"
					}]
					, "/path/to/file.cfc : 25"
					, ""
				]
			]
		};

	}

	public void function testAddRow() {

		makePublic( variables.cl, "addRow" );

		var row = [{
			"___class_name" = "User"
			, "name" = "Craig"
			, "occupation" = "NFL Player"
		}];
		var backtrace = "/path/to/file.cfc : 25";
		var severity = "";
		var actual = [];

		variables.cl.addRow( row, backtrace, severity );
		actual = variables.cl.getLogObject();

		assertEquals( variables.sampleLogObject, actual );

	}

	public void function testEncode() {

		makePublic( variables.cl, "encode" );

		// the sample log object was serialized manually and then base 64'ed by www.base64encode.org:
		var expected = "eyJyb3dzIjpbW1t7Im5hbWUiOiJDcmFpZyIsIm9jY3VwYXRpb24iOiJORkwgUGxheWVyIiwiX19fY2xhc3NfbmFtZSI6IlVzZXIifV0sIlwvcGF0aFwvdG9cL2ZpbGUuY2ZjIDogMjUiLCIiXV0sImNvbHVtbnMiOlsibG9nIiwiYmFja3RyYWNlIiwidHlwZSJdLCJ2ZXJzaW9uIjowLjF9";
		var actual = variables.cl.encode( variables.sampleLogObject );

		assertEquals( expected, actual );

	}

	public void function testResetShouldEmptyLogObjectRows() {

		variables.cl.log( "test" );
		variables.cl.log( 123 );
		variables.cl.log( [] );

		assertEquals( 3, arrayLen( variables.cl.getLogObject().rows ) );

		variables.cl.reset();

		assertEquals( 0, arrayLen( variables.cl.getLogObject().rows ) );

	}

	public void function testConvertShouldNotModifySimpleValues() {

		makePublic( variables.cl, "convert" );

		var string = "i am a string";
		var numeric = 12345;
		var boolean = true;

		assertEquals( string, variables.cl.convert( string ) );
		assertEquals( numeric, variables.cl.convert( numeric ) );
		assertEquals( boolean, variables.cl.convert( boolean ) );

	}

	public void function testConvertShouldNotModifyStructs() {

		makePublic( variables.cl, "convert" );

		var struct = { "key" = "value" };

		assertEquals( struct, variables.cl.convert( struct ) );

	}

	public void function testConvertShouldNotModifyArrays() {

		makePublic( variables.cl, "convert" );

		var array = [ 1, 2, 3, 4, 5 ];

		assertEquals( array, variables.cl.convert( array ) );

	}

	public void function testConvertShouldNotModifyExceptions() {

		makePublic( variables.cl, "convert" );

		var exception = "";

		try {

			throw();

		} catch( Any e ) {

			exception = e;

		}

		assertEquals( exception, variables.cl.convert( exception ) );

	}

	public void function testConvertShouldReturnStructRepresentationOfObject() {

		makePublic( variables.cl, "convert" );

		var object = new User();
		var result = "";

		object.setID( 123 );
		object.setName( "Craig" );
		object.setOccupation( "NFL Player" );

		result = variables.cl.convert( object );

		// i can't do a direct assertEquals here because the ___class_name will change depending
		// on your path to the component.
		assertIsStruct( result );
		assertEquals( "User", listLast( result[ "___class_name" ], "." ) );

		assertTrue( structKeyExists( result, "id" ) );
		assertTrue( structKeyExists( result, "name" ) );
		assertTrue( structKeyExists( result, "occupation" ) );

		assertEquals( 123, result.id );
		assertEquals( "Craig", result.name );
		assertEquals( "NFL Player", result.occupation );

	}

	public void function testConvertShouldNotRecurseInfinitelyOnCircularReferences() {

		makePublic( variables.cl, "convert" );

		var user = new User();
		var address = new Address();
		var result = "";

		user.setID( 123 );
		user.setName( "Craig" );
		user.setOccupation( "NFL Player" );
		user.setAddress( address );

		address.setID( 456 );
		address.setStreet( "Test Blvd." );
		address.setUser( user );

		result = variables.cl.convert( user );

		assertIsStruct( result.address );

		// the path can change based on mappings etc, but the basic format for notifying the
		// user of recursion is as follows:
		// recursion - parent object [ chromelogger.test.User ]
		assertTrue( result.address.user contains "recursion - parent object [" );

	}

	public void function testIsRecursionReturnsTrueForIdenticalObjects() {

		makePublic( variables.cl, "isRecursion" );

		var obj1 = new User();
		var obj2 = obj1;

		assertTrue( variables.cl.isRecursion( obj1, obj2 ) );

	}

	public void function testIsRecursionReturnsTrueForSavedObject() {

		makePublic( variables.cl, "isRecursion" );
		makePublic( variables.cl, "saveProcessedObject" );

		var obj1 = new Address();
		var obj2 = new User();

		variables.cl.saveProcessedObject( obj2 );

		assertTrue( variables.cl.isRecursion( obj1, obj2 ) );

	}

	public void function testIsRecursionReturnsFalseForNonIdenticalObjects() {

		makePublic( variables.cl, "isRecursion" );

		var obj1 = new User();
		var obj2 = new Address();

		assertFalse( variables.cl.isRecursion( obj1, obj2 ) );

	}

	public void function testGetRecursionString() {

		makePublic( variables.cl, "getRecursionString" );

		var actual = variables.cl.getRecursionString( this );

		// the path can change based on mappings etc, but the basic format for notifying the
		// user of recursion is as follows:
		// recursion - parent object [ chromelogger.test.User ]
		assertTrue( actual contains "recursion - parent object [" );

	}

	public void function testArgsToArray() {

		makePublic( variables.cl, "argsToArray" );

		// mxunit complains about not being able to successfully
		// compare objects, but the test still passes.
		var sampleArgs = {
			1 = "string"
			, 2 = 12345
			, 3 = { "inner" = "struct" }
			, 4 = [ "inner", "array" ]
			// , 5 = this
		};
		var expected = [
			"string"
			, 12345
			, { "inner" = "struct" }
			, [ "inner", "array" ]
			// , this
		];
		var actual = variables.cl.argsToArray( sampleArgs );

		assertEquals( expected, actual );

	}

	public void function testGetBacktrace() {

		makePublic( variables.cl, "getBacktrace" );

		var trace = variables.cl.getBacktrace();
		var traceArray = listToArray( trace, " : ", false, true );
		var path = traceArray[ 1 ];
		var line = traceArray[ 2 ];

		// because makePublic proxies the method, we can't actually verify
		// that the file path and line number are correct here, so the best
		// we can do is verify that the first half of the backtrace is a string
		// and the second half is numeric. backtrace is in the format of
		// "/path/to/component.cfc : 35"
		assertTrue(
			!isNull( path )
			&& !isNumeric( path )
			&& len( path )
		);
		assertTrue(
			!isNull( line )
			&& isNumeric( line )
		);

	}

	public void function testIsExceptionReturnsTrueForExceptions() {

		makePublic( variables.cl, "isException" );

		var exception = "";

		try {

			throw();

		} catch( Any e ) {

			exception = e;

		}

		assertTrue( variables.cl.isException( exception ) );

	}

	public void function testIsExceptionReturnsFalseForSimpleValues() {

		makePublic( variables.cl, "isException" );

		var string = "i am a string";
		var numeric = 12345;
		var boolean = true;

		assertFalse( variables.cl.isException( string ) );
		assertFalse( variables.cl.isException( numeric ) );
		assertFalse( variables.cl.isException( boolean ) );

	}

	public void function testIsExceptionReturnsFalseForStructs() {

		makePublic( variables.cl, "isException" );

		var struct = { "key" = "value" };

		assertFalse( variables.cl.isException( struct ) );

	}

	public void function testIsExceptionReturnsFalseForArrays() {

		makePublic( variables.cl, "isException" );

		var array = [ 1, 2, 3, 4, 5 ];

		assertFalse( variables.cl.isException( array ) );

	}

	public void function testIsExceptionReturnsFalseForQueries() {

		makePublic( variables.cl, "isException" );

		var query = queryNew( "some,columns,and,stuff" );

		assertFalse( variables.cl.isException( query ) );

	}

	public void function testIsExceptionReturnsFalseForObjects() {

		makePublic( variables.cl, "isException" );

		var object = this;

		assertFalse( variables.cl.isException( object ) );

	}

	public void function testIsMethodReturnsTrueForMethods() {

		makePublic( variables.cl, "isMethod" );

		var method = this.testIsMethodReturnsTrueForMethods;

		assertTrue( variables.cl.isMethod( method ) );

	}

	public void function testIsMethodReturnsFalseForExceptions() {

		makePublic( variables.cl, "isMethod" );

		var exception = "";

		try {

			throw();

		} catch( Any e ) {

			exception = e;

		}

		assertFalse( variables.cl.isMethod( exception ) );

	}

	public void function testIsMethodReturnsFalseForSimpleValues() {

		makePublic( variables.cl, "isMethod" );

		var string = "i am a string";
		var numeric = 12345;
		var boolean = true;

		assertFalse( variables.cl.isMethod( string ) );
		assertFalse( variables.cl.isMethod( numeric ) );
		assertFalse( variables.cl.isMethod( boolean ) );

	}

	public void function testIsMethodReturnsFalseForStructs() {

		makePublic( variables.cl, "isMethod" );

		var struct = { "key" = "value" };

		assertFalse( variables.cl.isMethod( struct ) );

	}

	public void function testIsMethodReturnsFalseForArrays() {

		makePublic( variables.cl, "isMethod" );

		var array = [ 1, 2, 3, 4, 5 ];

		assertFalse( variables.cl.isMethod( array ) );

	}

	public void function testIsMethodReturnsFalseForQueries() {

		makePublic( variables.cl, "isMethod" );

		var query = queryNew( "some,columns,and,stuff" );

		assertFalse( variables.cl.isMethod( query ) );

	}

	public void function testIsMethodReturnsFalseForObjects() {

		makePublic( variables.cl, "isMethod" );

		var object = this;

		assertFalse( variables.cl.isMethod( object ) );

	}

}